#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
================================================================================
 SET-ICAP HOL - Generador de datos históricos sintéticos del mercado FX SET-FX
================================================================================
 Genera ~1 año de operaciones de divisas realistas del mercado cambiario
 colombiano (USD/COP y cruces) y las sube a S3 como CSV gzip (delimitador ';').

 Modelo: catálogos (currency, mercado, paridad_moneda, sub_mercado, ciiu) +
 maestros (entidad, sucursal, usuario, comitente) + transaccionales
 (operation_set_fx, operation_set_fx_contraparte).

 Uso:
   export AWS_PROFILE=contributor-484577546576
   ~/miniforge3/bin/python gen_set_icap_datos.py --upload
   (sin --upload solo genera local en ./out/)

 Datos 100% sintéticos para fines demostrativos. No representan operaciones
 reales de SET-ICAP ni de las entidades mencionadas.
================================================================================
"""
import argparse
import gzip
import io
import os
import datetime as dt
import numpy as np
import pandas as pd

RNG = np.random.default_rng(20260619)  # semilla fija -> reproducible

S3_BUCKET = "demosjparrado"
S3_PREFIX = "set_icap_hol/hist"
OUT_DIR = os.path.join(os.path.dirname(__file__), "out")

# ----------------------------------------------------------------------------
# Parámetros del mercado
# ----------------------------------------------------------------------------
FECHA_INI = dt.date(2025, 6, 19)
FECHA_FIN = dt.date(2026, 6, 19)
HORA_APERTURA = dt.time(8, 0, 0)   # 8:00 COT
HORA_CIERRE   = dt.time(13, 0, 0)  # 1:00 PM COT
OPS_POR_DIA_MEDIA = 450            # operaciones promedio por día hábil


# ----------------------------------------------------------------------------
# 1. CATÁLOGOS
# ----------------------------------------------------------------------------
def gen_currency():
    rows = [
        # curr_id, currency, alias, signo, alias_deceval, coddeceval
        (1,  "Peso Colombiano",   "COP", "$",   "COP", "170"),
        (2,  "Dólar Americano",   "USD", "US$", "USD", "840"),
        (3,  "Euro",              "EUR", "€",   "EUR", "978"),
        (4,  "Libra Esterlina",   "GBP", "£",   "GBP", "826"),
        (5,  "Peso Mexicano",     "MXN", "MX$", "MXN", "484"),
        (6,  "Real Brasileño",    "BRL", "R$",  "BRL", "986"),
        (7,  "Dólar Canadiense",  "CAD", "C$",  "CAD", "124"),
        (8,  "Yen Japonés",       "JPY", "¥",   "JPY", "392"),
        (9,  "Franco Suizo",      "CHF", "Fr",  "CHF", "756"),
        (10, "Dólar Australiano", "AUD", "A$",  "AUD", "036"),
    ]
    return pd.DataFrame(rows, columns=[
        "curr_id", "curr_currency", "curr_alias", "curr_signo",
        "curr_alias_deceval", "curr_coddeceval"])


def gen_mercado():
    rows = [
        # mercado_id, prod_id, activo, nombre
        (76, 1, True,  "Contado USD/COP"),
        (77, 1, True,  "Next Day USD/COP"),
        (78, 2, True,  "Forward USD/COP"),
        (79, 3, True,  "Swap USD/COP"),
        (80, 4, True,  "Spot EUR/USD"),
        (81, 5, True,  "Forward EUR/COP"),
        (82, 6, True,  "OIS Tasa de Cambio"),
        (83, 7, True,  "Contado USD/MXN"),
        (84, 8, False, "Contado USD/BRL"),
        (85, 9, True,  "Non-Delivery Forward USD/COP"),
    ]
    return pd.DataFrame(rows, columns=[
        "mercado_id", "prod_id", "activo", "mercado_nombre"])


def gen_paridad():
    rows = [
        # paridad_id, nombre, moneda_uno, moneda_dos, paridad_to_uds, activa
        (1, "USD/COP", 2, 1, 1.0,    True),
        (2, "EUR/COP", 3, 1, 1.08,   True),
        (3, "EUR/USD", 3, 2, 1.08,   True),
        (4, "GBP/USD", 4, 2, 1.27,   True),
        (5, "USD/MXN", 2, 5, 1.0,    True),
        (6, "USD/BRL", 2, 6, 1.0,    False),
        (7, "USD/CAD", 2, 7, 1.0,    True),
        (8, "USD/JPY", 2, 8, 1.0,    True),
    ]
    return pd.DataFrame(rows, columns=[
        "paridad_id", "nombre", "moneda_uno", "moneda_dos",
        "paridad_to_uds", "paridad_activa"])


def gen_sub_mercado():
    rows = [
        (1, 76, 1, True,  "Interbancario Spot",  True),
        (2, 76, 2, True,  "Cliente Spot",        False),
        (3, 77, 1, True,  "Interbancario NextDay", True),
        (4, 78, 1, True,  "Interbancario Forward", True),
        (5, 78, 2, True,  "Cliente Forward",     False),
        (6, 79, 1, True,  "Interbancario Swap",  True),
        (7, 80, 1, True,  "Spot Internacional",  True),
        (8, 81, 2, True,  "Cliente Forward EUR", False),
        (9, 85, 1, True,  "NDF Offshore",        True),
        (10, 76, 3, True, "IMC-IMC",             True),
    ]
    return pd.DataFrame(rows, columns=[
        "sub_mercado_id", "mercado_id", "sub_mercado", "activo",
        "submercado_nombre", "sumercado_interbancario"])


def gen_ciiu():
    rows = [
        ("K6419", "K", "64", "641", "6419", "Otros tipos de intermediación monetaria"),
        ("K6492", "K", "64", "649", "6492", "Otras actividades de distribución de fondos"),
        ("K6499", "K", "64", "649", "6499", "Otras actividades de servicio financiero"),
        ("K6611", "K", "66", "661", "6611", "Administración de mercados financieros"),
        ("K6612", "K", "66", "661", "6612", "Corretaje de valores y de contratos"),
        ("K6499", "K", "64", "649", "6499", "Fideicomisos y fondos"),
        ("K6512", "K", "65", "651", "6512", "Seguros generales"),
        ("C1011", "C", "10", "101", "1011", "Procesamiento de carnes"),
        ("B0510", "B", "05", "051", "0510", "Extracción de hulla (carbón de piedra)"),
        ("B0610", "B", "06", "061", "0610", "Extracción de petróleo crudo"),
        ("C1921", "C", "19", "192", "1921", "Fabricación de productos de la refinación del petróleo"),
        ("G4631", "G", "46", "463", "4631", "Comercio al por mayor de productos alimenticios"),
        ("H4923", "H", "49", "492", "4923", "Transporte de carga por carretera"),
        ("D3511", "D", "35", "351", "3511", "Generación de energía eléctrica"),
        ("J6110", "J", "61", "611", "6110", "Actividades de telecomunicaciones alámbricas"),
    ]
    df = pd.DataFrame(rows, columns=[
        "codigo", "seccion", "division", "grupo", "clase", "descripcion"])
    return df


# ----------------------------------------------------------------------------
# 2. MAESTROS
# ----------------------------------------------------------------------------
# IMCs reales del mercado cambiario colombiano (Intermediarios del Mercado Cambiario)
ENTIDADES = [
    # nombre, sigla, clase, tipo, formador_liquidez, creador_mercado
    ("Banco de la República",                "BANREP",   "Banco Central",          "Oficial",  True,  True),
    ("Bancolombia S.A.",                     "BANCOLOM", "Banco",                  "Privado",  True,  True),
    ("Banco de Bogotá S.A.",                 "BBOGOTA",  "Banco",                  "Privado",  True,  True),
    ("Banco Davivienda S.A.",                "DAVIV",    "Banco",                  "Privado",  True,  True),
    ("BBVA Colombia S.A.",                   "BBVA",     "Banco",                  "Privado",  True,  True),
    ("Banco de Occidente S.A.",              "OCCID",    "Banco",                  "Privado",  True,  False),
    ("Itaú Colombia S.A.",                   "ITAU",     "Banco",                  "Privado",  True,  True),
    ("Scotiabank Colpatria S.A.",            "COLPAT",   "Banco",                  "Privado",  True,  False),
    ("Banco Popular S.A.",                   "POPULAR",  "Banco",                  "Privado",  False, False),
    ("Banco GNB Sudameris S.A.",             "GNB",      "Banco",                  "Privado",  True,  False),
    ("Citibank Colombia S.A.",               "CITI",     "Banco",                  "Extranjero", True, True),
    ("JPMorgan Chase Bank Colombia",         "JPM",      "Banco",                  "Extranjero", True, True),
    ("Banco Santander Colombia S.A.",        "SANTAN",   "Banco",                  "Extranjero", True, True),
    ("Banco Agrario de Colombia S.A.",       "AGRARIO",  "Banco",                  "Oficial",  False, False),
    ("Banco Caja Social S.A.",               "BCS",      "Banco",                  "Privado",  False, False),
    ("Banco AV Villas S.A.",                 "AVVILLAS", "Banco",                  "Privado",  False, False),
    ("Banco Falabella S.A.",                 "FALABEL",  "Banco",                  "Privado",  False, False),
    ("Banco Pichincha S.A.",                 "PICHIN",   "Banco",                  "Extranjero", False, False),
    ("Bancoomeva S.A.",                      "COOMEVA",  "Banco",                  "Cooperativo", False, False),
    ("Banco Serfinanza S.A.",                "SERFIN",   "Banco",                  "Privado",  False, False),
    ("Banco W S.A.",                         "BANCOW",   "Banco",                  "Privado",  False, False),
    ("Bancamía S.A.",                        "BANCAMIA", "Banco",                  "Privado",  False, False),
    ("Banco Finandina S.A.",                 "FINAND",   "Banco",                  "Privado",  False, False),
    ("Banco Mundo Mujer S.A.",               "MMUJER",   "Banco",                  "Privado",  False, False),
    ("Coltefinanciera S.A.",                 "COLTEF",   "Compañía de Financiamiento", "Privado", False, False),
    ("Credicorp Capital Colombia S.A.",      "CREDIC",   "Comisionista",           "Privado",  True,  False),
    ("Corredores Davivienda S.A.",           "CORRDAV",  "Comisionista",           "Privado",  True,  False),
    ("Acciones y Valores S.A.",              "ACCVAL",   "Comisionista",           "Privado",  False, False),
    ("Alianza Valores S.A.",                 "ALIANZA",  "Comisionista",           "Privado",  False, False),
    ("BTG Pactual Colombia S.A.",            "BTG",      "Comisionista",           "Extranjero", True, True),
    ("Casa de Bolsa S.A.",                   "CASABOL",  "Comisionista",           "Privado",  False, False),
    ("Global Securities S.A.",               "GLOBAL",   "Comisionista",           "Privado",  False, False),
    ("Servivalores GNB Sudameris S.A.",      "SERVGNB",  "Comisionista",           "Privado",  False, False),
    ("Valores Bancolombia S.A.",             "VALBANC",  "Comisionista",           "Privado",  True,  False),
    ("Ultraserfinco S.A.",                   "ULTRA",    "Comisionista",           "Privado",  False, False),
    ("Corficolombiana S.A.",                 "CORFICOL", "Corporación Financiera", "Privado",  True,  False),
    ("Banco Cooperativo Coopcentral",        "COOPCENT", "Banco",                  "Cooperativo", False, False),
    ("Mibanco S.A.",                         "MIBANCO",  "Banco",                  "Privado",  False, False),
    ("Financiera de Desarrollo Nacional",    "FDN",      "Banco",                  "Oficial",  False, False),
    ("Bancóldex S.A.",                       "BANCOLDX", "Banco",                  "Oficial",  False, False),
    ("Goldman Sachs Colombia",               "GS",       "Comisionista",           "Extranjero", True, True),
    ("Banco BTG Pactual",                    "BTGBANK",  "Banco",                  "Extranjero", True, False),
    ("Larrainvial Colombia S.A.",            "LARRAIN",  "Comisionista",           "Extranjero", False, False),
    ("Banco Tequendama",                     "TEQUEND",  "Banco",                  "Privado",  False, False),
    ("Fiduciaria Bancolombia S.A.",          "FIDUBANC", "Fiduciaria",             "Privado",  False, False),
    ("Fiduciaria Bogotá S.A.",               "FIDUBOG",  "Fiduciaria",             "Privado",  False, False),
    ("Skandia Valores S.A.",                 "SKANDIA",  "Comisionista",           "Privado",  False, False),
    ("Profesionales de Bolsa S.A.",          "PROFBOL",  "Comisionista",           "Privado",  False, False),
    ("Banco Multibank Colombia",             "MULTIB",   "Banco",                  "Extranjero", False, False),
    ("Davivienda Corredores Internacional",  "DAVINTL",  "Comisionista",           "Extranjero", False, False),
]

CIUDADES = ["Bogotá", "Medellín", "Cali", "Barranquilla", "Cartagena",
            "Bucaramanga", "Pereira", "Manizales"]


def gen_entidad():
    rows = []
    for i, (nombre, sigla, clase, tipo, fl, cm) in enumerate(ENTIDADES, start=1):
        nit = f"{RNG.integers(800000000, 900000000)}-{RNG.integers(0,9)}"
        cod_superfin = f"{RNG.integers(1, 99):02d}"
        ciudad = "Bogotá" if i <= 30 else RNG.choice(CIUDADES)
        fecha_vinc = dt.date(2005, 1, 1) + dt.timedelta(days=int(RNG.integers(0, 6500)))
        rows.append((
            i,                                  # entidad_id
            f"E{i:04d}",                         # entidad_codigo
            sigla,                               # entidad_sigla
            nombre,                              # entidad_nombre
            nit,                                 # entidad_nit
            ciudad,                              # entidad_ciudad
            "Colombia",                          # entidad_pais
            cod_superfin,                        # entidad_cod_superfin
            clase,                               # entidad_clase
            tipo,                                # entidad_tipo
            True,                                # entidad_activa
            fl,                                  # entidad_formador_liquidez
            cm,                                  # entidad_creador_mercado
            fecha_vinc.isoformat(),              # entidad_fecha_vinculacion
        ))
    return pd.DataFrame(rows, columns=[
        "entidad_id", "entidad_codigo", "entidad_sigla", "entidad_nombre",
        "entidad_nit", "entidad_ciudad", "entidad_pais", "entidad_cod_superfin",
        "entidad_clase", "entidad_tipo", "entidad_activa",
        "entidad_formador_liquidez", "entidad_creador_mercado",
        "entidad_fecha_vinculacion"])


def gen_sucursal(df_ent):
    rows = []
    sid = 1
    for _, e in df_ent.iterrows():
        n_suc = int(RNG.integers(1, 5))  # 1-4 mesas/sucursales por entidad
        for k in range(n_suc):
            ciudad = e["entidad_ciudad"] if k == 0 else RNG.choice(CIUDADES)
            rows.append((
                sid,
                f"{e['entidad_sigla']}-{k+1:02d}",          # sucursal_sigla
                f"Cra {RNG.integers(1,100)} # {RNG.integers(1,100)}-{RNG.integers(1,99)}",
                f"60{RNG.integers(1,8)}{RNG.integers(1000000,9999999)}",
                ciudad,
                "Colombia",
                int(e["entidad_id"]),                        # entidad_id
                f"Mesa de Dinero {ciudad} - {e['entidad_sigla']}",
            ))
            sid += 1
    return pd.DataFrame(rows, columns=[
        "sucursal_id", "sucursal_sigla", "sucursal_direccion",
        "sucursal_telefono", "sucursal_ciudad", "sucursal_pais",
        "entidad_id", "sucursal_nombre"])


NOMBRES = ["Andrés", "Camila", "Santiago", "Valentina", "Sebastián", "Daniela",
           "Mateo", "Laura", "Nicolás", "Sofía", "Juan", "María", "Carlos",
           "Ana", "Felipe", "Carolina", "David", "Paula", "Diego", "Natalia",
           "Julián", "Catalina", "Esteban", "Manuela", "Ricardo", "Tatiana"]
APELLIDOS = ["Rodríguez", "Gómez", "González", "Martínez", "López", "García",
             "Pérez", "Sánchez", "Ramírez", "Torres", "Díaz", "Vargas",
             "Moreno", "Jiménez", "Rojas", "Castro", "Ortiz", "Suárez",
             "Galvis", "Mendoza", "Cárdenas", "Restrepo", "Quintero", "Ríos"]


def _user_code():
    # códigos tipo O597, O5D1, O6LJ (1 letra + 3 alfanum)
    chars = "0123456789ABCDEFGHJKLMNPQRSTUVWXYZ"
    return "O" + "".join(RNG.choice(list(chars), size=3))


def gen_usuario(df_suc):
    rows = []
    uid = 1
    used_codes = set()
    for _, s in df_suc.iterrows():
        n_tr = int(RNG.integers(1, 5))  # 1-4 traders por sucursal
        for _ in range(n_tr):
            code = _user_code()
            while code in used_codes:
                code = _user_code()
            used_codes.add(code)
            nom = f"{RNG.choice(NOMBRES)} {RNG.choice(APELLIDOS)}"
            iniciales = "".join([w[0] for w in nom.split()][:3]).upper()
            rows.append((
                uid,
                code,                                   # usuario_user_code
                bool(RNG.random() < 0.3),               # usuario_primary_user
                f"{RNG.integers(10000000, 1200000000)}",# usuario_documento
                "CC",                                   # usuario_tipo_doc
                nom,                                    # usuario_nombre
                iniciales,                              # usuario_siglas
                int(s["sucursal_id"]),                  # sucursal_id
            ))
            uid += 1
    return pd.DataFrame(rows, columns=[
        "usuario_id", "usuario_user_code", "usuario_primary_user",
        "usuario_documento", "usuario_tipo_doc", "usuario_nombre",
        "usuario_siglas", "sucursal_id"])


SECTORES_INV = ["Sector Real", "Fondo de Inversión", "Persona Natural",
                "Sector Público", "Inversionista Extranjero", "Fiduciaria",
                "Fondo de Pensiones", "Aseguradora", "Multinacional"]
PAISES_OFF = ["Colombia", "Estados Unidos", "Panamá", "Islas Caimán",
              "Reino Unido", "España", "Luxemburgo", "Chile", "México", "Brasil"]


def gen_comitente(df_ent, n=800):
    ciiu = gen_ciiu()["codigo"].tolist()
    rows = []
    for i in range(1, n + 1):
        es_off = RNG.random() < 0.35
        pais = RNG.choice(PAISES_OFF[1:]) if es_off else "Colombia"
        rows.append((
            i,                                       # offshore_id
            "NIT" if RNG.random() < 0.7 else "PAS",  # tipo_identificacion
            f"{RNG.integers(800000000, 999999999)}", # identificacion
            f"Comitente {i:04d} {RNG.choice(['SAS','S.A.','Ltda','Corp','Fund','Trust'])}",
            RNG.choice(ciiu),                        # sector (CIIU)
            int(RNG.choice(df_ent['entidad_id'])),   # codigo_imc
            RNG.choice(SECTORES_INV),                # tipo_inversionista
            pais,                                    # pais
            bool(RNG.random() < 0.2),                # autoretenedor
            es_off,                                  # enviar_informe_offshore
        ))
    return pd.DataFrame(rows, columns=[
        "offshore_id", "tipo_identificacion", "identificacion", "nombre",
        "sector", "codigo_imc", "tipo_inversionista", "pais",
        "autoretenedor", "enviar_informe_offshore"])


# ----------------------------------------------------------------------------
# 3. SERIE DE TRM (random walk anclado a medias mensuales realistas)
# ----------------------------------------------------------------------------
def business_days(d0, d1):
    days = []
    d = d0
    while d <= d1:
        if d.weekday() < 5:  # lun-vie
            days.append(d)
        d += dt.timedelta(days=1)
    return days


# Anclas mensuales realistas COP/USD (jun-2025 -> jun-2026): peso se aprecia
ANCLAS = {
    (2025, 6): 4150, (2025, 7): 4080, (2025, 8): 4020, (2025, 9): 3980,
    (2025, 10): 4050, (2025, 11): 4180, (2025, 12): 4320, (2026, 1): 4250,
    (2026, 2): 4100, (2026, 3): 3950, (2026, 4): 3820, (2026, 5): 3650,
    (2026, 6): 3445,
}


def trm_diaria(days):
    serie = {}
    prev = ANCLAS[(2025, 6)]
    for d in days:
        ancla = ANCLAS.get((d.year, d.month), prev)
        # reversión a la media mensual + ruido
        prev = prev + 0.15 * (ancla - prev) + RNG.normal(0, 12)
        serie[d] = round(prev, 2)
    return serie


# ----------------------------------------------------------------------------
# 4. OPERACIONES (vectorizado por día)
# ----------------------------------------------------------------------------
PLAZOS = ["T+0", "T+1", "T+2", "1W", "1M", "3M", "6M", "1Y"]
PLAZO_DIAS = {"T+0": 0, "T+1": 1, "T+2": 2, "1W": 7, "1M": 30,
              "3M": 90, "6M": 180, "1Y": 360}
NOTAS_MERCADO = [
    "Mercado con fuerte demanda de dólares por pago de importaciones.",
    "Presión vendedora por ingreso de divisas de exportadores petroleros.",
    "Volatilidad alta tras decisión de tasas del Banco de la República.",
    "Jornada tranquila, spreads ajustados entre IMC.",
    "Intervención del Banco de la República estabiliza la TRM.",
    "Apetito por riesgo eleva la oferta de dólares en el mercado spot.",
    "Cierre con tendencia alcista por incertidumbre fiscal.",
    "Liquidez reducida en la última hora de negociación.",
    "Demanda corporativa sostenida durante toda la sesión.",
    "Operaciones forward activas anticipando vencimientos de fin de mes.",
]


def gen_operaciones(df_ent, df_suc, df_usr, df_com, trm):
    days = list(trm.keys())
    op_rows = []
    cp_rows = []
    oid = 22000000
    mcod_seq = 0

    ent_ids = df_ent["entidad_id"].to_numpy()
    # peso por tamaño: bancos grandes operan más
    peso_ent = np.ones(len(ent_ids), dtype=float)
    peso_ent[:11] = 8.0   # banrep + grandes
    peso_ent[11:25] = 3.0
    peso_ent = peso_ent / peso_ent.sum()

    suc_by_ent = df_suc.groupby("entidad_id")["sucursal_id"].apply(list).to_dict()
    usr_by_suc = df_usr.groupby("sucursal_id")["usuario_id"].apply(list).to_dict()
    usr_code = dict(zip(df_usr["usuario_id"], df_usr["usuario_user_code"]))
    com_ids = df_com["offshore_id"].to_numpy()

    for d in days:
        n = max(50, int(RNG.normal(OPS_POR_DIA_MEDIA, 90)))
        spot = trm[d]
        # mercado: 76 contado domina (70%), resto distribuido
        mercados = RNG.choice([76, 77, 78, 79, 85, 80],
                              size=n, p=[0.62, 0.10, 0.12, 0.06, 0.05, 0.05])
        # compradores y vendedores (distintos)
        idx_c = RNG.choice(len(ent_ids), size=n, p=peso_ent)
        idx_v = RNG.choice(len(ent_ids), size=n, p=peso_ent)
        same = idx_c == idx_v
        idx_v[same] = (idx_v[same] + 1) % len(ent_ids)

        # montos USD: lognormal, 250k-1M típico, cola hasta 10M
        montos = np.round(np.exp(RNG.normal(13.0, 0.8, size=n)) / 50000) * 50000
        montos = np.clip(montos, 50000, 15000000)

        # precio intradía: spot + ruido + spread segun mercado
        ruido = RNG.normal(0, spot * 0.0015, size=n)
        precios = np.round(spot + ruido, 2)

        # hora aleatoria 8:00-13:00
        segs = RNG.integers(0, 5 * 3600, size=n)

        for k in range(n):
            oid += 1
            mcod_seq += 1
            merc = int(mercados[k])
            eid_c = int(ent_ids[idx_c[k]])
            eid_v = int(ent_ids[idx_v[k]])
            monto = float(montos[k])
            precio = float(precios[k])
            # plazo según mercado
            if merc in (76,):
                plazo = "T+1"; pf = 0.0
            elif merc == 77:
                plazo = "T+0"; pf = 0.0
            elif merc in (78, 85):
                plazo = RNG.choice(["1M", "3M", "6M", "1Y"]); pf = round(RNG.normal(15, 8), 2)
            elif merc == 79:
                plazo = RNG.choice(["1W", "1M", "3M"]); pf = round(RNG.normal(8, 5), 2)
            else:
                plazo = "T+2"; pf = 0.0
            pdias = PLAZO_DIAS[plazo]
            hora = (dt.datetime.combine(d, HORA_APERTURA) +
                    dt.timedelta(seconds=int(segs[k])))
            hora_post = hora - dt.timedelta(seconds=int(RNG.integers(5, 600)))
            fecha_valor = d + dt.timedelta(days=pdias if pdias > 0 else 1)
            anulada = RNG.random() < 0.015
            usuario_post = usr_code.get(
                int(RNG.choice(usr_by_suc.get(
                    suc_by_ent.get(eid_c, [None])[0], [1]))), "O000")
            monto_cop = round(monto * precio, 2)
            nota = RNG.choice(NOTAS_MERCADO) if RNG.random() < 0.08 else ""

            op_rows.append((
                oid,                                    # id
                d.isoformat(),                          # fecha
                hora.strftime("%H:%M:%S"),              # hora
                anulada,                                # anulada
                merc,                                   # mercado
                int(RNG.choice([1,2,3,4,7,10])),        # sub_mercado
                bool(RNG.random() < 0.4),               # registro
                f"FWJI{mcod_seq:X}",                    # mcod_transaccion
                usuario_post,                           # usuario_postura
                pdias,                                  # dias
                fecha_valor.isoformat(),                # fecha_valor
                hora_post.strftime("%H:%M:%S"),         # hora_postura
                round(monto, 2),                        # monto_moneda_uno (USD)
                monto_cop,                              # monto_moneda_dos (COP)
                round(monto, 2),                        # monto_usd
                precio,                                 # precio
                pf,                                     # points_forward
                round(spot, 2),                         # precio_spot
                plazo,                                  # plazo_curva
                bool(RNG.random() < 0.05),              # entidad_publica_3c_1
                bool(RNG.random() < 0.5),               # bandera_fisico_compensacion
                1,                                      # paridad_id (USD/COP)
                "USD/COP",                              # paridad_nombre
                2,                                      # moneda_uno
                1,                                      # moneda_dos
                eid_c,                                  # entidad_compradora
                eid_v,                                  # entidad_vendedora
                pdias,                                  # plazo_dias
                bool(RNG.random() < 0.7),               # enviada_camara
                nota,                                   # texto_term
            ))

            # contrapartes (lado C y V)
            suc_c = suc_by_ent.get(eid_c, [None])[0]
            suc_v = suc_by_ent.get(eid_v, [None])[0]
            tr_c = int(RNG.choice(usr_by_suc.get(suc_c, [1])))
            tr_v = int(RNG.choice(usr_by_suc.get(suc_v, [1])))
            com_c = int(RNG.choice(com_ids)) if RNG.random() < 0.4 else None
            com_v = int(RNG.choice(com_ids)) if RNG.random() < 0.4 else None
            cp_rows.append((oid, "C", eid_c, suc_c, tr_c, None, com_c))
            cp_rows.append((oid, "V", eid_v, suc_v, tr_v, None, com_v))

    df_op = pd.DataFrame(op_rows, columns=[
        "id", "fecha", "hora", "anulada", "mercado", "sub_mercado", "registro",
        "mcod_transaccion", "usuario_postura", "dias", "fecha_valor",
        "hora_postura", "monto_moneda_uno", "monto_moneda_dos", "monto_usd",
        "precio", "points_forward", "precio_spot", "plazo_curva",
        "entidad_publica_3c_1", "bandera_fisico_compensacion", "paridad_id",
        "paridad_nombre", "moneda_uno", "moneda_dos", "entidad_compradora",
        "entidad_vendedora", "plazo_dias", "enviada_camara", "texto_term"])
    df_cp = pd.DataFrame(cp_rows, columns=[
        "oper_id", "oper_lado", "entidad_id", "sucursal_id", "trader_id",
        "broker_id", "comitente_id"])
    return df_op, df_cp


# ----------------------------------------------------------------------------
# 5. ESCRITURA / UPLOAD
# ----------------------------------------------------------------------------
def to_csv_gz_bytes(df):
    buf = io.BytesIO()
    with gzip.GzipFile(fileobj=buf, mode="wb") as gz:
        df.to_csv(gz, sep=";", index=False, header=True,
                  date_format="%Y-%m-%d %H:%M:%S",
                  na_rep="NULL")
    return buf.getvalue()


def write_local(name, data):
    os.makedirs(os.path.join(OUT_DIR, name), exist_ok=True)
    path = os.path.join(OUT_DIR, name, f"{name}.csv.gz")
    with open(path, "wb") as f:
        f.write(data)
    return path


def upload_s3(s3, name, data):
    key = f"{S3_PREFIX}/{name}/{name}.csv.gz"
    s3.put_object(Bucket=S3_BUCKET, Key=key, Body=data)
    return f"s3://{S3_BUCKET}/{key}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--upload", action="store_true", help="subir a S3")
    args = ap.parse_args()

    print("Generando catálogos y maestros...")
    cur = gen_currency()
    mer = gen_mercado()
    par = gen_paridad()
    sub = gen_sub_mercado()
    cii = gen_ciiu()
    ent = gen_entidad()
    suc = gen_sucursal(ent)
    usr = gen_usuario(suc)
    com = gen_comitente(ent)
    print(f"  entidad={len(ent)} sucursal={len(suc)} usuario={len(usr)} comitente={len(com)}")

    print("Generando serie de TRM y operaciones (1 año)...")
    days = business_days(FECHA_INI, FECHA_FIN)
    trm = trm_diaria(days)
    op, cp = gen_operaciones(ent, suc, usr, com, trm)
    print(f"  dias_habiles={len(days)} operation_set_fx={len(op):,} contraparte={len(cp):,}")
    print(f"  TRM rango: {min(trm.values()):.2f} - {max(trm.values()):.2f} COP/USD")

    tables = {
        "currency": cur, "mercado": mer, "paridad_moneda": par,
        "sub_mercado": sub, "ciiu": cii, "entidad": ent, "sucursal": suc,
        "usuario": usr, "comitente": com, "operation_set_fx": op,
        "operation_set_fx_contraparte": cp,
    }

    s3 = None
    if args.upload:
        import boto3
        s3 = boto3.Session(profile_name=os.environ.get(
            "AWS_PROFILE", "contributor-484577546576")).client("s3")

    for name, df in tables.items():
        data = to_csv_gz_bytes(df)
        path = write_local(name, data)
        size_mb = len(data) / 1e6
        if s3 is not None:
            uri = upload_s3(s3, name, data)
            print(f"  [S3] {name:32s} {len(df):>8,} filas  {size_mb:6.2f} MB -> {uri}")
        else:
            print(f"  [local] {name:32s} {len(df):>8,} filas  {size_mb:6.2f} MB -> {path}")

    print("Listo.")


if __name__ == "__main__":
    main()
