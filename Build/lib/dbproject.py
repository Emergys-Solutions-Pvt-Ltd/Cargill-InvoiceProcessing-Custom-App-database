#!/usr/bin/env python3
"""Database project helper used by the Build/*.sh scripts (standard library only).

Sub-commands
  build         assemble Artifacts/schema.sql (+ predeploy.sql, postdeploy.sql, object-manifest.json,
                build-report.json) from postgres/objects.sql and validate the project structure
  expected-sql  print a SQL query listing the manifest objects that are MISSING from a database
  bundle        combine the per-schema pgschema plans into deployment-plan.json, deployment.sql,
                deployment-summary.json and destructive-changes.json
  check         enforce the approval policy on deployment-plan.json (digest, destructive changes)
  report        write deployment-report.json / deployment-report.md

Exit codes: 0 ok, 1 error, 2 usage, 3 approval required / plan rejected, 5 validation failed.
"""
import argparse
import datetime as dt
import glob
import hashlib
import json
import os
import re
import sys

EXIT_ERROR, EXIT_USAGE, EXIT_APPROVAL, EXIT_VALIDATION = 1, 2, 3, 5
PLAN_FORMAT = 'dbproject-plan/1'


# ---------------------------------------------------------------------------------------------- helpers
def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def sha256_file(path):
    with open(path, 'rb') as fh:
        return sha256_bytes(fh.read())


def read_text(path):
    with open(path, encoding='utf-8') as fh:
        return fh.read().replace('\r\n', '\n')


def write_text(path, text):
    os.makedirs(os.path.dirname(path) or '.', exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(text)


def write_json(path, data):
    write_text(path, json.dumps(data, indent=2, sort_keys=False) + '\n')


def load_json(path):
    with open(path, encoding='utf-8') as fh:
        return json.load(fh)


def now_utc():
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace('+00:00', 'Z')


def canonical(data):
    return json.dumps(data, sort_keys=True, separators=(',', ':'), ensure_ascii=True)


def log(level, msg):
    sys.stderr.write('[%s] [%s] %s\n' % (now_utc(), level, msg))


# ------------------------------------------------------------------------------------------ SQL parsing
DOLLAR_QUOTE = re.compile(r'\$((?:[A-Za-z_][A-Za-z_0-9]*)?)\$.*?\$\1\$', re.S)
LINE_COMMENT = re.compile(r'--[^\n]*')
BLOCK_COMMENT = re.compile(r'/\*.*?\*/', re.S)
STRING = re.compile(r"'(?:[^']|'')*'")
IDENT = r'(?:"[^"]+"|[A-Za-z_][A-Za-z_0-9]*)'
QNAME = r'(%s)\.(%s)' % (IDENT, IDENT)

CREATE_PATTERNS = [
    ('table', re.compile(r'\bCREATE\s+(?:UNLOGGED\s+)?TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?' + QNAME, re.I)),
    ('materialized_view', re.compile(r'\bCREATE\s+MATERIALIZED\s+VIEW\s+(?:IF\s+NOT\s+EXISTS\s+)?' + QNAME, re.I)),
    ('view', re.compile(r'\bCREATE\s+(?:OR\s+REPLACE\s+)?(?:TEMP\w*\s+)?(?:RECURSIVE\s+)?VIEW\s+' + QNAME, re.I)),
    ('function', re.compile(r'\bCREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+' + QNAME, re.I)),
    ('procedure', re.compile(r'\bCREATE\s+(?:OR\s+REPLACE\s+)?PROCEDURE\s+' + QNAME, re.I)),
    ('type', re.compile(r'\bCREATE\s+TYPE\s+' + QNAME, re.I)),
    ('domain', re.compile(r'\bCREATE\s+DOMAIN\s+' + QNAME, re.I)),
    ('sequence', re.compile(r'\bCREATE\s+SEQUENCE\s+(?:IF\s+NOT\s+EXISTS\s+)?' + QNAME, re.I)),
    # indexes / triggers are named without schema; the schema is the one of the table
    ('index', re.compile(r'\bCREATE\s+(?:UNIQUE\s+)?INDEX\s+(?:CONCURRENTLY\s+)?(?:IF\s+NOT\s+EXISTS\s+)?(%s)\s+ON\s+(?:ONLY\s+)?%s' % (IDENT, QNAME), re.I)),
    ('trigger', re.compile(r'\bCREATE\s+(?:OR\s+REPLACE\s+)?(?:CONSTRAINT\s+)?TRIGGER\s+(%s)\s+.*?\bON\s+%s' % (IDENT, QNAME), re.I | re.S)),
]
# Statements that do not belong in declarative object files (data -> postdeploy/, one-time -> ManualMigrations/)
FORBIDDEN = [
    (re.compile(r'^\s*DROP\s+', re.I | re.M), 'DROP statement'),
    (re.compile(r'^\s*TRUNCATE\b', re.I | re.M), 'TRUNCATE statement'),
    (re.compile(r'^\s*DELETE\s+FROM\b', re.I | re.M), 'DELETE statement (data belongs in postdeploy/ or ManualMigrations/Data)'),
    (re.compile(r'^\s*INSERT\s+INTO\b', re.I | re.M), 'INSERT statement (reference data belongs in postdeploy/)'),
    (re.compile(r'^\s*UPDATE\s+\S+\s+SET\b', re.I | re.M), 'UPDATE statement (data belongs in postdeploy/ or ManualMigrations/Data)'),
    (re.compile(r'^\s*ALTER\s+TABLE\b(?![^;]*\bADD\s+CONSTRAINT\b)', re.I | re.M), 'ALTER TABLE (edit the CREATE TABLE instead; only ADD CONSTRAINT is allowed)'),
    (re.compile(r'^\s*\\', re.M), 'psql meta-command'),
    (re.compile(r'^\s*(BEGIN|COMMIT|ROLLBACK)\s*;', re.I | re.M), 'transaction control'),
]
SECRET_PATTERNS = [
    re.compile(r'postgres(?:ql)?://[^\s:/]+:[^\s@]+@', re.I),
    re.compile(r'\bpassword\s*=\s*[\'"][^\'"]+[\'"]', re.I),
    re.compile(r'\bPGPASSWORD\s*=', re.I),
]


DO_BLOCK = re.compile(r'^\s*DO\s*(\$(\w*)\$)(.*?)\1', re.I | re.M | re.S)
GUARDED_CONSTRAINT = re.compile(r'^\s*BEGIN\s+(?:IF\s+NOT\s+EXISTS\s*\(.*?\)\s*THEN\s+ALTER\s+TABLE\s+\S+\s+ADD\s+CONSTRAINT\s+[^;]+;\s*END\s+IF\s*;\s*)+END\s*;?\s*$', re.I | re.S)


def check_do_blocks(text):
    """Only one kind of DO block is declarative enough for an object file: a guarded
    'IF NOT EXISTS (...) THEN ALTER TABLE ... ADD CONSTRAINT ...' (circular foreign keys)."""
    bad = []
    for m in DO_BLOCK.finditer(BLOCK_COMMENT.sub(' ', LINE_COMMENT.sub(' ', text))):
        if not GUARDED_CONSTRAINT.match(m.group(3)):
            bad.append(m.group(0).strip()[:60])
    return bad


def unquote(ident):
    return ident[1:-1] if ident.startswith('"') else ident.lower()


def strip_sql(text):
    """Comments, dollar-quoted bodies and string literals removed (positions are not kept)."""
    text = BLOCK_COMMENT.sub(' ', text)
    text = LINE_COMMENT.sub(' ', text)
    text = DOLLAR_QUOTE.sub(" $body$ ", text)
    return STRING.sub("''", text)


def objects_in(text):
    """[(kind, schema, name, table)] defined by CREATE statements of one file."""
    found = []
    for kind, rx in CREATE_PATTERNS:
        for m in rx.finditer(text):
            if kind in ('index', 'trigger'):
                found.append((kind, unquote(m.group(2)), unquote(m.group(1)), unquote(m.group(3))))
            else:
                found.append((kind, unquote(m.group(1)), unquote(m.group(2)), None))
    return found


def references_in(text, schemas):
    refs = set()
    for m in re.finditer(r'\b(%s)\.([A-Za-z_][A-Za-z_0-9]*)\b' % '|'.join(map(re.escape, schemas)), text, re.I):
        refs.add((m.group(1).lower(), m.group(2).lower()))
    return refs


def parse_manifest(path):
    files = []
    for no, line in enumerate(read_text(path).split('\n'), 1):
        s = line.strip()
        if not s or s.startswith('--'):
            continue
        m = re.match(r'^\\i[r]?\s+(\S+)\s*$', s)
        if not m:
            raise ValueError('%s:%d: only "\\ir <file>" lines and comments are allowed: %s' % (path, no, s))
        files.append((no, m.group(1)))
    return files


# ------------------------------------------------------------------------------------------------ build
def cmd_build(a):
    root = os.path.abspath(a.root)
    src = os.path.join(root, a.source_dir)
    out = os.path.abspath(a.out)
    schemas = a.schemas.split()
    errors, warnings = [], []

    manifest_path = os.path.join(root, a.manifest)
    try:
        listed = parse_manifest(manifest_path)
    except (OSError, ValueError) as exc:
        log('ERROR', str(exc))
        return EXIT_VALIDATION
    manifest_dir = os.path.dirname(manifest_path)

    # 1. structure: listed files exist, are unique, and every object file is listed
    seen, ordered = {}, []
    for no, rel in listed:
        full = os.path.normpath(os.path.join(manifest_dir, rel))
        key = os.path.relpath(full, root).replace('\\', '/')
        if key in seen:
            errors.append('objects.sql:%d lists %s twice (first on line %d)' % (no, key, seen[key]))
            continue
        seen[key] = no
        if not os.path.isfile(full):
            errors.append('objects.sql:%d: missing file %s' % (no, key))
            continue
        ordered.append(key)

    excluded_dirs = {'tests', 'predeploy', 'postdeploy', 'seed', 'templates', 'tools'}
    excluded_files = {'objects.sql', 'deploy_schema.sql', 'reset_schema.sql'}
    for dp, dirs, fs in os.walk(src):
        dirs[:] = sorted(d for d in dirs if d not in excluded_dirs)
        for f in sorted(fs):
            if not f.endswith('.sql') or f in excluded_files or f.startswith('seed'):
                continue
            key = os.path.relpath(os.path.join(dp, f), root).replace('\\', '/')
            if key not in seen:
                errors.append('%s is not listed in %s (it would never be deployed)' % (key, a.manifest))

    predeploy = sorted(glob.glob(os.path.join(root, a.predeploy_dir, '*.sql')))
    postdeploy = sorted(glob.glob(os.path.join(root, a.postdeploy_dir, '*.sql')))
    if not predeploy:
        errors.append('no pre-deployment scripts in %s (schemas must be created there)' % a.predeploy_dir)

    # 2. objects, forbidden statements, secrets
    defined, files_out = {}, []
    for order, key in enumerate(ordered, 1):
        text = read_text(os.path.join(root, key))
        bare = strip_sql(text)
        for rx, what in FORBIDDEN:
            m = rx.search(bare)
            if m:
                errors.append('%s: %s is not allowed in an object file: "%s"' % (key, what, m.group(0).strip()[:60]))
        for snippet in check_do_blocks(text):
            errors.append('%s: DO block is not allowed in an object file (only guarded ADD CONSTRAINT): "%s"' % (key, snippet))
        for rx in SECRET_PATTERNS:
            if rx.search(text):
                errors.append('%s: looks like a credential / connection string' % key)
        objs = objects_in(bare)
        if not objs:
            errors.append('%s: defines no schema-qualified object (CREATE <kind> <schema>.<name>)' % key)
        file_objs = []
        for kind, schema, name, table in objs:
            if schema not in schemas:
                errors.append('%s: %s %s.%s is in schema "%s", which is not managed (config MANAGED_SCHEMAS)' % (key, kind, schema, name, schema))
            ident = (kind if kind not in ('function', 'procedure') else 'routine', schema, name)
            if ident in defined and defined[ident]['file'] != key:
                errors.append('%s: duplicate definition of %s %s.%s (also in %s)' % (key, kind, schema, name, defined[ident]['file']))
            defined.setdefault(ident, {'file': key, 'order': order, 'kind': kind})
            entry = {'kind': kind, 'schema': schema, 'name': name}
            if table:
                entry['table'] = table
            file_objs.append(entry)
        files_out.append({'order': order, 'path': key, 'sha256': sha256_file(os.path.join(root, key)),
                          'objects': file_objs, '_bare': bare})

    # 3. dependencies: schema-qualified references outside function bodies must exist and come first
    by_name = {}
    for (k, s, n), info in defined.items():
        by_name.setdefault((s, n), []).append(info)
    for f in files_out:
        own = {(o['schema'], o['name']) for o in f['objects']}
        for ref in sorted(references_in(f['_bare'], schemas)):
            if ref in own:
                continue
            targets = by_name.get(ref)
            if not targets:
                errors.append('%s: references %s.%s, which no project file defines (missing dependency)' % ((f['path'],) + ref))
            elif min(t['order'] for t in targets) > f['order']:
                t = min(targets, key=lambda x: x['order'])
                errors.append('%s: references %s.%s defined later in objects.sql (%s) - fix the order' % ((f['path'],) + ref + (t['file'],)))
        del f['_bare']

    for rel in [os.path.relpath(p, root).replace('\\', '/') for p in postdeploy]:
        bare = strip_sql(read_text(os.path.join(root, rel)))
        if re.search(r'^\s*(DROP|TRUNCATE|DELETE)\b', bare, re.I | re.M):
            errors.append('%s: post-deployment scripts must be idempotent and non-destructive (no DROP/TRUNCATE/DELETE)' % rel)

    # 4. artifacts (deterministic: no timestamps inside the SQL)
    def section(paths, title):
        parts = ['-- ' + '=' * 98, '-- %s' % title, '-- ' + '=' * 98]
        for rel in paths:
            parts.append('\n-- >>> source: %s\n' % rel)
            parts.append(read_text(os.path.join(root, rel)).rstrip() + '\n')
        return '\n'.join(parts) + '\n'

    pre_rel = [os.path.relpath(p, root).replace('\\', '/') for p in predeploy]
    post_rel = [os.path.relpath(p, root).replace('\\', '/') for p in postdeploy]
    header = ('-- Generated by Build/build-schema.sh from %s - do not edit.\n'
              '-- Complete desired state of schemas: %s. Install on an empty database with:\n'
              '--   psql -X -1 -v ON_ERROR_STOP=1 -f schema.sql   (then postdeploy.sql)\n\n' % (a.manifest, ', '.join(schemas)))
    write_text(os.path.join(out, 'predeploy.sql'), section(pre_rel, 'Pre-deployment (schemas, default privileges)'))
    write_text(os.path.join(out, 'schema.sql'), header + section(pre_rel, 'Pre-deployment (schemas, default privileges)')
               + '\n' + section(ordered, 'Schema objects (objects.sql order)'))
    write_text(os.path.join(out, 'postdeploy.sql'), section(post_rel, 'Post-deployment (idempotent reference data)'))

    kinds = {}
    for f in files_out:
        for o in f['objects']:
            kinds.setdefault(o['kind'], 0)
            kinds[o['kind']] += 1
    write_json(os.path.join(out, 'object-manifest.json'), {
        'manifest': a.manifest, 'schemas': schemas, 'predeploy': pre_rel, 'postdeploy': post_rel,
        'object_counts': dict(sorted(kinds.items())), 'files': files_out})
    report = {
        'status': 'failed' if errors else 'succeeded', 'generated_at': now_utc(),
        'source_commit': a.commit or None, 'files': len(ordered), 'objects': sum(kinds.values()),
        'object_counts': dict(sorted(kinds.items())),
        'schema_sql_sha256': sha256_file(os.path.join(out, 'schema.sql')),
        'predeploy_sql_sha256': sha256_file(os.path.join(out, 'predeploy.sql')),
        'postdeploy_sql_sha256': sha256_file(os.path.join(out, 'postdeploy.sql')),
        'errors': errors, 'warnings': warnings}
    write_json(os.path.join(out, 'build-report.json'), report)
    for e in errors:
        log('ERROR', e)
    log('INFO' if not errors else 'ERROR', 'build %s: %d files, %d objects %s' % (report['status'], len(ordered), report['objects'], kinds))
    return EXIT_VALIDATION if errors else 0


# ------------------------------------------------------------------------------- expected objects query
def cmd_expected_sql(a):
    m = load_json(a.manifest_json)
    rows = []
    for f in m['files']:
        for o in f['objects']:
            rows.append("('%s','%s','%s')" % (o['kind'], o['schema'], o['name'].replace("'", "''")))
    sys.stdout.write("""WITH expected(kind, schema_name, object_name) AS (VALUES
%s)
SELECT e.kind || ' ' || e.schema_name || '.' || e.object_name
FROM expected e
WHERE NOT CASE e.kind
    WHEN 'table' THEN EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                              WHERE n.nspname = e.schema_name AND c.relname = e.object_name AND c.relkind IN ('r','p'))
    WHEN 'view' THEN EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                             WHERE n.nspname = e.schema_name AND c.relname = e.object_name AND c.relkind = 'v')
    WHEN 'materialized_view' THEN EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                             WHERE n.nspname = e.schema_name AND c.relname = e.object_name AND c.relkind = 'm')
    WHEN 'index' THEN EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                              JOIN pg_index i ON i.indexrelid = c.oid
                              WHERE n.nspname = e.schema_name AND c.relname = e.object_name AND i.indisvalid)
    WHEN 'sequence' THEN EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                                 WHERE n.nspname = e.schema_name AND c.relname = e.object_name AND c.relkind = 'S')
    WHEN 'function' THEN EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                                 WHERE n.nspname = e.schema_name AND p.proname = e.object_name AND p.prokind IN ('f','a','w'))
    WHEN 'procedure' THEN EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                                  WHERE n.nspname = e.schema_name AND p.proname = e.object_name AND p.prokind = 'p')
    WHEN 'type' THEN EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                             WHERE n.nspname = e.schema_name AND t.typname = e.object_name)
    WHEN 'domain' THEN EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                               WHERE n.nspname = e.schema_name AND t.typname = e.object_name AND t.typtype = 'd')
    WHEN 'trigger' THEN EXISTS (SELECT 1 FROM pg_trigger g JOIN pg_class c ON c.oid = g.tgrelid
                                JOIN pg_namespace n ON n.oid = c.relnamespace
                                WHERE n.nspname = e.schema_name AND g.tgname = e.object_name AND g.tgenabled <> 'D')
    ELSE true END
ORDER BY 1;
""" % ',\n'.join(rows or ["('none','none','none')"]))
    return 0


# ----------------------------------------------------------------------------------------- plan bundle
DATA_LOSS_TYPES = {'table', 'table.column', 'sequence', 'materialized_view', 'type', 'domain'}


def classify(step):
    """-> (category, approval_required, reason)"""
    op, typ, sql = step.get('operation'), step.get('type', ''), step.get('sql', '')
    if op == 'drop':
        if typ in DATA_LOSS_TYPES:
            return 'data_loss', True, 'drops %s: data or a dependent definition is lost' % typ
        return 'breaking', True, 'drops %s: callers relying on it break' % typ
    if op == 'alter' and typ == 'table.column' and re.search(r'\bTYPE\b', sql, re.I):
        return 'review', False, 'column type change: may rewrite the table or narrow data'
    if op == 'alter' and typ == 'table.column' and re.search(r'\bSET\s+NOT\s+NULL\b', sql, re.I):
        return 'review', False, 'SET NOT NULL fails if existing rows hold NULL'
    if op == 'recreate':
        return 'review', False, '%s is dropped and recreated (dependent objects must be recreated too)' % typ
    return None, False, None


def non_transactional(step, group):
    sql = step.get('sql', '')
    return bool(re.search(r'\bCONCURRENTLY\b', sql, re.I) or 'pgschema:wait' in sql
                or group.get('transaction') is False or step.get('can_run_in_transaction') is False)


def cmd_bundle(a):
    art = os.path.abspath(a.artifacts)
    build = load_json(os.path.join(art, 'build-report.json'))
    schemas_out, steps_all, destructive, preview = [], [], [], []
    pgschema_version = None
    counts = {'create': 0, 'alter': 0, 'drop': 0, 'recreate': 0}
    by_type = {}
    status_lines = load_json(a.status_json) if a.status_json else {}

    preview.append('-- Deployment preview generated by Build/generate-plan.sh - review only.\n'
                   '-- Applied by Build/deploy.sh apply from deployment-plan.json (pgschema apply --plan per schema).\n'
                   '-- Environment: %s   Plan mode: %s\n' % (a.environment, a.mode))
    if a.mode == 'bootstrap':
        preview.append('\n-- ===== Bootstrap: empty target, the complete schema (Artifacts/schema.sql) in one transaction =====\n'
                       + read_text(os.path.join(art, 'schema.sql')))
    else:
        preview.append('\n-- ===== Pre-deployment (idempotent) =====\n' + read_text(os.path.join(art, 'predeploy.sql')))
    for schema in a.schemas.split():
        plan_path = os.path.join(art, 'plans', schema + '.json')
        entry = {'schema': schema, 'status': status_lines.get(schema, 'planned')}
        if a.mode == 'bootstrap':
            entry.update({'status': 'bootstrap', 'steps': None})
            schemas_out.append(entry)
            continue
        if not os.path.isfile(plan_path):
            log('ERROR', 'missing plan for schema %s (%s)' % (schema, plan_path))
            return EXIT_ERROR
        plan = load_json(plan_path)
        pgschema_version = plan.get('pgschema_version', pgschema_version)
        groups = plan.get('groups') or []
        n = 0
        for gi, g in enumerate(groups):
            for st in g.get('steps') or []:
                n += 1
                counts[st.get('operation', 'other')] = counts.get(st.get('operation', 'other'), 0) + 1
                key = '%s:%s' % (st.get('type'), st.get('operation'))
                by_type[key] = by_type.get(key, 0) + 1
                cat, approval, reason = classify(st)
                item = {'schema': schema, 'group': gi, 'type': st.get('type'), 'operation': st.get('operation'),
                        'path': st.get('path'), 'sql': st.get('sql'),
                        'non_transactional': non_transactional(st, g)}
                steps_all.append(item)
                if cat:
                    destructive.append(dict(item, category=cat, approval_required=approval, reason=reason))
        entry.update({'status': 'changes' if n else 'no_changes', 'steps': n,
                      'plan_file': 'plans/%s.json' % schema, 'plan_sha256': sha256_file(plan_path),
                      'source_fingerprint': (plan.get('source_fingerprint') or {}).get('hash'),
                      'pgschema_version': plan.get('pgschema_version'), 'plan_format': plan.get('version')})
        schemas_out.append(entry)
        sql_path = os.path.join(art, 'plans', schema + '.sql')
        body = read_text(sql_path).strip() if os.path.isfile(sql_path) else ''
        preview.append('\n-- ===== Schema %s: %s =====\n' % (schema, '%d step(s)' % n if n else 'no changes'))
        if body:
            preview.append('SET search_path TO %s;\n%s\n' % (schema, body))
    preview.append('\n-- ===== Post-deployment (idempotent reference data) =====\n' + read_text(os.path.join(art, 'postdeploy.sql')))

    approval_needed = [d for d in destructive if d['approval_required']]
    # Digest: everything that decides what will run, nothing time-dependent (created_at is excluded)
    digest_src = {
        'format': PLAN_FORMAT, 'mode': a.mode, 'environment': a.environment,
        'schema_sql_sha256': build['schema_sql_sha256'], 'predeploy_sql_sha256': build['predeploy_sql_sha256'],
        'postdeploy_sql_sha256': build['postdeploy_sql_sha256'],
        'schemas': [{'schema': s['schema'], 'status': s['status'], 'fingerprint': s.get('source_fingerprint'),
                     'steps': [x['sql'] for x in steps_all if x['schema'] == s['schema']]} for s in schemas_out]}
    digest = sha256_bytes(canonical(digest_src).encode())
    has_changes = a.mode == 'bootstrap' or any(s['status'] == 'changes' for s in schemas_out)

    plan_doc = {
        'format': PLAN_FORMAT, 'digest': digest, 'created_at': now_utc(), 'environment': a.environment,
        'mode': a.mode, 'has_changes': has_changes,
        'target': {'database': a.target_db, 'host_sha256': sha256_bytes(a.target_host.encode())[:16] if a.target_host else None,
                   'server_version': a.server_version or None},
        'source': {'repository': a.repo or None, 'branch': a.branch or None, 'commit': a.commit or None,
                   'schema_sql_sha256': build['schema_sql_sha256'], 'predeploy_sql_sha256': build['predeploy_sql_sha256'],
                   'postdeploy_sql_sha256': build['postdeploy_sql_sha256']},
        'pgschema_version': pgschema_version, 'schemas': schemas_out,
        'destructive': {'count': len(destructive), 'approval_required': len(approval_needed) > 0},
        'non_transactional_steps': sum(1 for s in steps_all if s['non_transactional'])}
    write_json(os.path.join(art, 'deployment-plan.json'), plan_doc)
    write_json(os.path.join(art, 'destructive-changes.json'), {
        'digest': digest, 'environment': a.environment, 'approval_required': len(approval_needed) > 0,
        'changes': destructive})
    write_json(os.path.join(art, 'deployment-summary.json'), {
        'digest': digest, 'environment': a.environment, 'mode': a.mode, 'has_changes': has_changes,
        'operations': counts, 'by_type': dict(sorted(by_type.items())),
        'schemas': [{k: s.get(k) for k in ('schema', 'status', 'steps')} for s in schemas_out],
        'destructive_changes': len(destructive), 'approval_required': len(approval_needed) > 0,
        'non_transactional_steps': plan_doc['non_transactional_steps']})
    write_text(os.path.join(art, 'deployment.sql'), ''.join(preview))
    print(digest)
    log('INFO', 'plan %s: mode=%s changes=%s destructive=%d (approval required: %s)'
        % (digest[:12], a.mode, has_changes, len(destructive), bool(approval_needed)))
    return 0


def cmd_check(a):
    plan = load_json(os.path.join(a.artifacts, 'deployment-plan.json'))
    problems = []
    if plan.get('format') != PLAN_FORMAT:
        problems.append('unknown plan format %r' % plan.get('format'))
    for s in plan['schemas']:
        if s.get('plan_file'):
            p = os.path.join(a.artifacts, s['plan_file'])
            if not os.path.isfile(p) or sha256_file(p) != s['plan_sha256']:
                problems.append('plan file for schema %s is missing or was modified after planning' % s['schema'])
            if s.get('pgschema_version') and a.pgschema_version and s['pgschema_version'] != a.pgschema_version:
                problems.append('schema %s was planned with pgschema %s, this image has %s'
                                % (s['schema'], s['pgschema_version'], a.pgschema_version))
    if plan['environment'] != a.environment:
        problems.append('plan was generated for %s, not %s' % (plan['environment'], a.environment))
    if problems:
        for p in problems:
            log('ERROR', p)
        return EXIT_VALIDATION
    if a.approved_digest and a.approved_digest.strip().lower() != plan['digest']:
        log('ERROR', 'approved plan digest %s does not match the current plan %s: the source or the target changed '
                     'since the review - review the new plan' % (a.approved_digest.strip()[:12], plan['digest'][:12]))
        return EXIT_APPROVAL
    if a.require_approval and plan['has_changes'] and not a.approved_digest:
        log('ERROR', 'this environment requires the reviewed plan digest (approved_plan_digest=%s)' % plan['digest'])
        return EXIT_APPROVAL
    if plan['destructive']['approval_required'] and not a.allow_destructive:
        log('ERROR', 'the plan contains destructive steps (see destructive-changes.json); re-run with '
                     'ALLOW_DESTRUCTIVE=true after review')
        return EXIT_APPROVAL
    log('INFO', 'plan %s accepted (changes=%s, destructive=%d)' % (plan['digest'][:12], plan['has_changes'],
                                                                   plan['destructive']['count']))
    return 0


# ----------------------------------------------------------------------------------------------- report
def cmd_report(a):
    art = os.path.abspath(a.artifacts)
    opt = lambda name: load_json(os.path.join(art, name)) if os.path.isfile(os.path.join(art, name)) else None
    plan, summary, destr = opt('deployment-plan.json'), opt('deployment-summary.json'), opt('destructive-changes.json')
    build, verify = opt('build-report.json'), opt('verify-report.json')
    tools = opt('tool-versions.json') or {}
    errors = [l.strip() for l in (open(a.errors_file, encoding='utf-8').read().splitlines() if a.errors_file and os.path.isfile(a.errors_file) else []) if l.strip()]
    created = modified = deleted = []
    if plan:
        steps = []
        for s in plan['schemas']:
            if s.get('plan_file') and os.path.isfile(os.path.join(art, s['plan_file'])):
                for g in load_json(os.path.join(art, s['plan_file'])).get('groups') or []:
                    steps.extend(g.get('steps') or [])
        created = sorted({x['path'] for x in steps if x.get('operation') == 'create'})
        modified = sorted({x['path'] for x in steps if x.get('operation') in ('alter', 'recreate')})
        deleted = sorted({x['path'] for x in steps if x.get('operation') == 'drop'})
    rep = {
        'repository': a.repo or None, 'branch': a.branch or None, 'commit': a.commit or None,
        'environment': a.environment, 'mode': a.mode, 'status': a.status,
        'postgres_version': a.server_version or None, 'timestamp': now_utc(),
        'plan_digest': plan and plan['digest'], 'plan_mode': plan and plan['mode'],
        'objects_created': created, 'objects_modified': modified, 'objects_deleted': deleted,
        'bootstrap': bool(plan and plan['mode'] == 'bootstrap'),
        'destructive_operations': (destr or {}).get('changes', []),
        'summary': summary, 'build': build and {k: build[k] for k in ('status', 'files', 'objects', 'schema_sql_sha256')},
        'verification': verify, 'errors': errors, 'tool_versions': tools}
    write_json(os.path.join(art, 'deployment-report.json'), rep)
    md = ['# Database deployment report', '',
          '| Item | Value |', '|---|---|',
          '| Status | **%s** |' % a.status, '| Mode | %s |' % a.mode, '| Environment | %s |' % a.environment,
          '| Repository | %s |' % (a.repo or '-'), '| Branch | %s |' % (a.branch or '-'), '| Commit | %s |' % (a.commit or '-'),
          '| PostgreSQL | %s |' % (a.server_version or '-'), '| Timestamp | %s |' % rep['timestamp'],
          '| Plan digest | `%s` |' % (rep['plan_digest'] or '-'), '| Plan mode | %s |' % (rep['plan_mode'] or '-'),
          '| Tools | %s |' % ', '.join('%s %s' % kv for kv in sorted(tools.items())) or '-', '']
    if rep['bootstrap']:
        md += ['Empty target: the complete schema (schema.sql) was installed.', '']
    for title, items in (('Created', created), ('Modified', modified), ('Deleted', deleted)):
        md += ['## %s (%d)' % (title, len(items)), ''] + ['- `%s`' % i for i in items[:200]] + ([''] if items else ['None.', ''])
    md += ['## Destructive / review items (%d)' % len(rep['destructive_operations']), '']
    for d in rep['destructive_operations']:
        md.append('- **%s** `%s` %s - %s%s' % (d['category'], d['path'], d['operation'], d['reason'],
                                               ' (approval required)' if d['approval_required'] else ''))
    if not rep['destructive_operations']:
        md.append('None.')
    md += ['', '## Verification', '']
    if verify:
        md += ['- %s: %s' % (k, v) for k, v in verify.items() if k != 'missing_objects'] + \
              ['- missing objects: %s' % (', '.join(verify.get('missing_objects') or []) or 'none')]
    else:
        md.append('Not run.')
    md += ['', '## Errors', ''] + (['- ' + e for e in errors] or ['None.'])
    write_text(os.path.join(art, 'deployment-report.md'), '\n'.join(md) + '\n')
    return 0


# ------------------------------------------------------------------------------------------------- main
def main(argv):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest='cmd', required=True)
    b = sub.add_parser('build')
    b.add_argument('--root', required=True)
    b.add_argument('--out', required=True)
    b.add_argument('--source-dir', default='postgres')
    b.add_argument('--manifest', default='postgres/objects.sql')
    b.add_argument('--predeploy-dir', default='postgres/predeploy')
    b.add_argument('--postdeploy-dir', default='postgres/postdeploy')
    b.add_argument('--schemas', required=True)
    b.add_argument('--commit', default='')
    e = sub.add_parser('expected-sql')
    e.add_argument('--manifest-json', required=True)
    u = sub.add_parser('bundle')
    for opt in ('--artifacts', '--schemas', '--environment', '--mode'):
        u.add_argument(opt, required=True)
    for opt in ('--target-db', '--target-host', '--server-version', '--repo', '--branch', '--commit', '--status-json'):
        u.add_argument(opt, default='')
    c = sub.add_parser('check')
    c.add_argument('--artifacts', required=True)
    c.add_argument('--environment', required=True)
    c.add_argument('--approved-digest', default='')
    c.add_argument('--require-approval', action='store_true')
    c.add_argument('--allow-destructive', action='store_true')
    c.add_argument('--pgschema-version', default='')
    r = sub.add_parser('report')
    for opt in ('--artifacts', '--environment', '--mode', '--status'):
        r.add_argument(opt, required=True)
    for opt in ('--repo', '--branch', '--commit', '--server-version', '--errors-file'):
        r.add_argument(opt, default='')
    a = p.parse_args(argv)
    return {'build': cmd_build, 'expected-sql': cmd_expected_sql, 'bundle': cmd_bundle,
            'check': cmd_check, 'report': cmd_report}[a.cmd](a)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
