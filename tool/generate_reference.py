#!/usr/bin/env python3
"""Genera los paquetes de referencia (semilla de fábrica) desde las tablas
expandidas z-score de la OMS (WHO Child Growth Standards, 0–5 años).

Es un script de un solo uso, **no** se compila en la app. Produce:

  assets/reference/seed_index.json
  assets/reference/oms-2006/manifest.json + tables/*.csv   (LMS por indicador y sexo)
  assets/reference/col-2465/manifest.json                  (solo clasificación; usa las curvas OMS)
  test/fixtures/who_spot_checks.dart                       (cortes SD publicados para tests)

Uso:
    python3 tool/generate_reference.py            # descarga (o usa caché) y genera
    python3 tool/generate_reference.py --offline  # exige caché en tool/.cache/xlsx

El parseo de .xlsx usa solo la stdlib (zipfile + ElementTree): un .xlsx es un zip
de XML, así que no hace falta openpyxl ni el paquete `excel` de Dart.

Procedencia: las URLs se EXTRAEN de las páginas de cada indicador porque el nombre
de carpeta varía por indicador (expanded-tables vs expandable-tables). No se fijan.
"""
import argparse
import hashlib
import json
import math
import os
import re
import sys
import urllib.request
import zipfile
from datetime import date
from xml.etree import ElementTree as ET

NS = '{http://schemas.openxmlformats.org/spreadsheetml/2006/main}'
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(ROOT, 'tool', '.cache', 'xlsx')
ASSETS = os.path.join(ROOT, 'assets', 'reference')
FIXTURE = os.path.join(ROOT, 'test', 'fixtures', 'who_spot_checks.dart')

GENERATED_AT = date.today().isoformat()
SOURCE = 'WHO Child Growth Standards — expanded z-score tables (who.int), 2006/2007'

# Páginas de las que se extraen los enlaces .xlsx.
PAGES = {
    'weight-for-age': 'https://www.who.int/tools/child-growth-standards/standards/weight-for-age',
    'length-height-for-age': 'https://www.who.int/tools/child-growth-standards/standards/length-height-for-age',
    'weight-for-length-height': 'https://www.who.int/tools/child-growth-standards/standards/weight-for-length-height',
    'head-circumference-for-age': 'https://www.who.int/tools/child-growth-standards/standards/head-circumference-for-age',
    'bmi-for-age': 'https://www.who.int/toolkits/child-growth-standards/standards/body-mass-index-for-age-bmi-for-age',
}

# Cada tabla: nombre local -> (patrón de enlace a buscar, kind, sex, axis, subtype).
# El patrón identifica el archivo z-score expandido dentro de la página.
TABLES = [
    ('wfa_boys',  'wfa-boys-zscore-expanded',   'weightForAge',             'boys',  'ageDays',   None),
    ('wfa_girls', 'wfa-girls-zscore-expanded',  'weightForAge',             'girls', 'ageDays',   None),
    ('lhfa_boys', 'lhfa-boys-zscore-expanded',  'statureForAge',            'boys',  'ageDays',   None),
    ('lhfa_girls','lhfa-girls-zscore-expanded', 'statureForAge',            'girls', 'ageDays',   None),
    ('wfl_boys',  'wfl-boys-zscore-expanded',   'weightForStature',         'boys',  'statureCm', 'length'),
    ('wfl_girls', 'wfl-girls-zscore-expanded',  'weightForStature',         'girls', 'statureCm', 'length'),
    ('wfh_boys',  'wfh-boys-zscore-expanded',   'weightForStature',         'boys',  'statureCm', 'height'),
    ('wfh_girls', 'wfh-girls-zscore-expanded',  'weightForStature',         'girls', 'statureCm', 'height'),
    ('bfa_boys',  'bfa-boys-zscore-expanded',   'bmiForAge',                'boys',  'ageDays',   None),
    ('bfa_girls', 'bfa-girls-zscore-expanded',  'bmiForAge',                'girls', 'ageDays',   None),
    ('hcfa_boys', 'hcfa-boys-zscore-expanded',  'headCircumferenceForAge',  'boys',  'ageDays',   None),
    ('hcfa_girls','hcfa-girls-zscore-expanded', 'headCircumferenceForAge',  'girls', 'ageDays',   None),
]

PAGE_OF_KIND = {
    'weightForAge': 'weight-for-age',
    'statureForAge': 'length-height-for-age',
    'weightForStature': 'weight-for-length-height',
    'bmiForAge': 'bmi-for-age',
    'headCircumferenceForAge': 'head-circumference-for-age',
}


def fetch(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'anthro-calculator-app/generator'})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def resolve_urls():
    """Extrae de cada página el enlace .xlsx que corresponde a cada tabla."""
    page_html = {}
    for key, url in PAGES.items():
        page_html[key] = fetch(url).decode('utf-8', 'replace')
    urls = {}
    for name, pattern, kind, sex, axis, subtype in TABLES:
        html = page_html[PAGE_OF_KIND[kind]]
        links = re.findall(r'https://cdn\.who\.int[^"\'\s]*\.xlsx', html)
        match = next((l for l in links if pattern in l), None)
        if not match:
            raise SystemExit(f'No se encontró el enlace para {name} (patrón {pattern})')
        urls[name] = match
    return urls


def ensure_xlsx(offline):
    os.makedirs(CACHE, exist_ok=True)
    urls = {}
    need_resolve = not offline and any(
        not os.path.exists(os.path.join(CACHE, f'{n}.xlsx')) for n, *_ in TABLES
    )
    if need_resolve:
        urls = resolve_urls()
    for name, *_ in TABLES:
        path = os.path.join(CACHE, f'{name}.xlsx')
        if os.path.exists(path):
            continue
        if offline:
            raise SystemExit(f'Falta {path} y --offline está activo')
        print(f'  descargando {name} …')
        with open(path, 'wb') as f:
            f.write(fetch(urls[name]))
    return urls


def read_sheet(path):
    z = zipfile.ZipFile(path)
    shared = []
    try:
        sroot = ET.fromstring(z.read('xl/sharedStrings.xml'))
        shared = [''.join(t.text or '' for t in si.iter(f'{NS}t'))
                  for si in sroot.findall(f'{NS}si')]
    except KeyError:
        pass
    root = ET.fromstring(z.read('xl/worksheets/sheet1.xml'))
    data = root.find(f'{NS}sheetData')
    rows = []
    for r in data.findall(f'{NS}row'):
        cells = {}
        for c in r.findall(f'{NS}c'):
            col = re.match(r'[A-Z]+', c.get('r')).group(0)
            v = c.find(f'{NS}v')
            val = v.text if v is not None else None
            if c.get('t') == 's' and val is not None:
                val = shared[int(val)]
            cells[col] = val
        rows.append(cells)
    return rows


# Columnas: A=key B=L C=M D=S E=SD4neg F=SD3neg G=SD2neg H=SD1neg I=SD0 J..M SD1..SD4
SD_COLS = {'SD3neg': 'F', 'SD2neg': 'G', 'SD2': 'K', 'SD3': 'L'}


def parse_table(path, axis):
    rows = read_sheet(path)
    header = rows[0]
    assert header['B'] == 'L' and header['C'] == 'M' and header['D'] == 'S', \
        f'Cabecera inesperada en {path}: {header}'
    out = []      # (key, L, M, S)
    cuts = {}     # key -> {SD3neg, SD2neg, SD2, SD3}
    for cells in rows[1:]:
        if cells.get('A') is None:
            continue
        raw = float(cells['A'])
        key = int(round(raw)) if axis == 'ageDays' else round(raw, 1)
        L, M, S = float(cells['B']), float(cells['C']), float(cells['D'])
        out.append((key, L, M, S))
        cuts[key] = {name: float(cells[col]) for name, col in SD_COLS.items()}
    out.sort(key=lambda t: t[0])
    # Claves estrictamente crecientes.
    for i in range(1, len(out)):
        assert out[i][0] > out[i - 1][0], f'Clave no creciente en {path}: {out[i]}'
    return out, cuts


def value_from_lms(z, L, M, S):
    if abs(L) < 1e-7:
        return M * math.exp(S * z)
    return M * (1 + L * S * z) ** (1.0 / L)


def fmt(x):
    """Representación compacta y estable (8 cifras significativas)."""
    s = '%.8g' % x
    return s


def write_csv(name, table):
    d = os.path.join(ASSETS, 'oms-2006', 'tables')
    os.makedirs(d, exist_ok=True)
    path = os.path.join(d, f'{name}.csv')
    lines = ['key,L,M,S']
    for key, L, M, S in table:
        keystr = str(key) if isinstance(key, int) else ('%g' % key)
        lines.append(f'{keystr},{fmt(L)},{fmt(M)},{fmt(S)}')
    body = '\n'.join(lines) + '\n'
    with open(path, 'w') as f:
        f.write(body)
    sha = hashlib.sha256(body.encode('utf-8')).hexdigest()
    return path, len(table), sha


def validate_reconstruction(name, table, cuts):
    """Validación clínica: reconstruir ±2/±3 DS desde L,M,S debe reproducir
    las columnas publicadas del xlsx dentro de ±0.01."""
    worst = 0.0
    for key, L, M, S in table:
        c = cuts[key]
        for z, col in ((-3, 'SD3neg'), (-2, 'SD2neg'), (2, 'SD2'), (3, 'SD3')):
            got = value_from_lms(z, L, M, S)
            worst = max(worst, abs(got - c[col]))
    assert worst <= 0.01, f'{name}: reconstrucción SD falla, peor error {worst:.4f}'
    return worst


# ---- Bandas de clasificación (Z). Ordenadas ascendente; aplica el primer ltZ
# ---- que cumpla z < ltZ (null = infinito). El COLOR NO sale de aquí, sale de
# ---- statusFromZ en el motor. Estas cadenas necesitan revisión clínica.
def bands(*pairs):
    return [{'ltZ': lt, 'label': lb} for lt, lb in pairs]

CLASSIFICATION_OMS = {
    'weightForAge': bands(
        (-3, 'Peso muy bajo para la edad'), (-2, 'Peso bajo para la edad'),
        (-1, 'Riesgo de peso bajo para la edad'), (1, 'Peso adecuado para la edad'),
        (2, 'Peso elevado para la edad'), (None, 'Peso muy elevado para la edad')),
    'statureForAge': bands(
        (-3, 'Talla baja severa para la edad'), (-2, 'Talla baja para la edad'),
        (-1, 'Riesgo de talla baja'), (None, 'Talla adecuada para la edad')),
    'weightForStature': bands(
        (-3, 'Desnutrición aguda severa'), (-2, 'Desnutrición aguda moderada'),
        (-1, 'Riesgo de desnutrición aguda'), (1, 'Peso adecuado para la talla'),
        (2, 'Riesgo de sobrepeso'), (3, 'Sobrepeso'), (None, 'Obesidad')),
    'bmiForAge': bands(
        (-3, 'Delgadez severa'), (-2, 'Delgadez'),
        (-1, 'Riesgo de delgadez'), (1, 'Estado nutricional normal'),
        (2, 'Riesgo de sobrepeso'), (3, 'Sobrepeso'), (None, 'Obesidad')),
    'headCircumferenceForAge': bands(
        (-3, 'Microcefalia severa'), (-2, 'Microcefalia — requiere valoración'),
        (-1, 'Perímetro cefálico en límite inferior'), (1, 'Perímetro cefálico normal'),
        (2, 'Perímetro cefálico en límite superior'), (None, 'Macrocefalia — requiere valoración')),
}

# Colombia (Resolución 2465 de 2016): adopta las curvas OMS; cambia la redacción.
CLASSIFICATION_COL = {
    'weightForAge': bands(
        (-3, 'Peso muy bajo para la edad'), (-2, 'Peso bajo para la edad'),
        (-1, 'Riesgo de peso bajo para la edad'), (1, 'Peso adecuado para la edad'),
        (None, 'Peso adecuado para la edad')),
    'statureForAge': bands(
        (-3, 'Talla baja para la edad o retraso en talla'),
        (-2, 'Talla baja para la edad o retraso en talla'),
        (-1, 'Riesgo de talla baja'), (None, 'Talla adecuada para la edad')),
    'weightForStature': bands(
        (-3, 'Desnutrición aguda severa'), (-2, 'Desnutrición aguda moderada'),
        (-1, 'Riesgo de desnutrición aguda'), (1, 'Peso adecuado para la talla'),
        (2, 'Sobrepeso'), (3, 'Sobrepeso'), (None, 'Obesidad')),
    'bmiForAge': bands(
        (-3, 'Delgadez'), (-2, 'Delgadez'),
        (-1, 'Riesgo de delgadez'), (1, 'IMC adecuado para la edad'),
        (2, 'Sobrepeso'), (3, 'Sobrepeso'), (None, 'Obesidad')),
    'headCircumferenceForAge': bands(
        (-3, 'Microcefalia severa'), (-2, 'Microcefalia — requiere valoración'),
        (-1, 'Perímetro cefálico en límite inferior'), (1, 'Perímetro cefálico normal'),
        (2, 'Perímetro cefálico en límite superior'), (None, 'Macrocefalia — requiere valoración')),
}

VALIDITY = {
    'weightForAge': {'axis': 'ageDays', 'min': 0, 'max': 1856},
    'statureForAge': {'axis': 'ageDays', 'min': 0, 'max': 1856},
    'bmiForAge': {'axis': 'ageDays', 'min': 0, 'max': 1856},
    'headCircumferenceForAge': {'axis': 'ageDays', 'min': 0, 'max': 1856},
    'weightForStature': {'axis': 'statureCm', 'length': {'min': 45.0, 'max': 110.0},
                         'height': {'min': 65.0, 'max': 120.0}},
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--offline', action='store_true', help='exige xlsx en tool/.cache/xlsx')
    args = ap.parse_args()

    print('1) Obteniendo xlsx …')
    urls = ensure_xlsx(args.offline)

    print('2) Parseando, validando y escribiendo CSV …')
    table_entries = []
    spot_rows = []
    for name, pattern, kind, sex, axis, subtype in TABLES:
        path = os.path.join(CACHE, f'{name}.xlsx')
        table, cuts = parse_table(path, axis)
        worst = validate_reconstruction(name, table, cuts)
        csv_path, rows, sha = write_csv(name, table)
        entry = {'kind': kind, 'sex': sex, 'axis': axis,
                 'file': f'tables/{name}.csv', 'rows': rows, 'sha256': sha}
        if subtype:
            entry['subtype'] = subtype
        if name in urls:
            entry['sourceUrl'] = urls[name]
        # Puntos de control SD (inicio, medio, fin): la instalación reconstruye
        # ±2/±3 DS desde L,M,S y compara con estos cortes publicados (±0.01).
        checks = []
        for idx in (0, len(table) // 2, len(table) - 1):
            key = table[idx][0]
            c = cuts[key]
            checks.append({'key': key, 'sd3neg': c['SD3neg'], 'sd2neg': c['SD2neg'],
                           'sd2': c['SD2'], 'sd3': c['SD3']})
        entry['sdChecks'] = checks
        table_entries.append(entry)
        print(f'   {name:11s} filas={rows:<5} sha={sha[:12]}… reconstrucción≤{worst:.4f}')

        # ~1 fila por tabla para el fixture de spot-check (día 365 o 90 cm).
        pick = 365 if axis == 'ageDays' else 90.0
        row = next((t for t in table if abs(t[0] - pick) < 1e-6), table[len(table) // 2])
        c = cuts[row[0]]
        spot_rows.append((name, kind, sex, row[0], c['SD3neg'], c['SD2neg'], c['SD2'], c['SD3'],
                          row[1], row[2], row[3]))

    print('3) Escribiendo manifiestos …')
    oms_manifest = {
        'schemaVersion': 1,
        'standardId': 'oms-2006',
        'displayName': 'OMS 2006 · 0–5 años',
        'version': '2006.1',
        'generatedAt': GENERATED_AT,
        'source': SOURCE,
        'validity': VALIDITY,
        'tables': table_entries,
        'classification': CLASSIFICATION_OMS,
    }
    os.makedirs(os.path.join(ASSETS, 'oms-2006'), exist_ok=True)
    with open(os.path.join(ASSETS, 'oms-2006', 'manifest.json'), 'w') as f:
        json.dump(oms_manifest, f, ensure_ascii=False, indent=2)

    col_manifest = {
        'schemaVersion': 1,
        'standardId': 'col-2465',
        'displayName': 'Colombia · Resolución 2465 de 2016',
        'version': '2016.1',
        'generatedAt': GENERATED_AT,
        'source': 'Resolución 2465 de 2016 (Colombia) — adopta las curvas OMS 2006/2007',
        'tablesFrom': 'oms-2006',
        'validity': VALIDITY,
        'classification': CLASSIFICATION_COL,
    }
    os.makedirs(os.path.join(ASSETS, 'col-2465'), exist_ok=True)
    with open(os.path.join(ASSETS, 'col-2465', 'manifest.json'), 'w') as f:
        json.dump(col_manifest, f, ensure_ascii=False, indent=2)

    seed_index = {
        'schemaVersion': 1,
        'packages': [
            {'standardId': 'oms-2006', 'dir': 'oms-2006'},
            {'standardId': 'col-2465', 'dir': 'col-2465'},
        ],
    }
    with open(os.path.join(ASSETS, 'seed_index.json'), 'w') as f:
        json.dump(seed_index, f, ensure_ascii=False, indent=2)

    print('4) Escribiendo fixture de spot-checks …')
    os.makedirs(os.path.dirname(FIXTURE), exist_ok=True)
    lines = [
        '// GENERADO por tool/generate_reference.py — no editar a mano.',
        '// Cortes SD publicados por la OMS, para verificar valueFromLms contra la fuente.',
        '',
        'class WhoSpotCheck {',
        '  const WhoSpotCheck(this.table, this.kind, this.sex, this.key,',
        '      this.sd3neg, this.sd2neg, this.sd2, this.sd3, this.l, this.m, this.s);',
        '  final String table, kind, sex;',
        '  final double key, sd3neg, sd2neg, sd2, sd3, l, m, s;',
        '}',
        '',
        'const List<WhoSpotCheck> kWhoSpotChecks = [',
    ]
    for name, kind, sex, key, sd3n, sd2n, sd2, sd3, L, M, S in spot_rows:
        lines.append(
            f"  WhoSpotCheck('{name}', '{kind}', '{sex}', {float(key)}, "
            f'{sd3n}, {sd2n}, {sd2}, {sd3}, {L}, {M}, {S}),')
    lines.append('];')
    with open(FIXTURE, 'w') as f:
        f.write('\n'.join(lines) + '\n')

    print('Listo.')


if __name__ == '__main__':
    main()
