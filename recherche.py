"""recherche.py : version corrigée (liste blanche, sql.Identifier, pas d'erreur affichée)."""
import psycopg
from psycopg import sql

TRIS = {"code": sql.Identifier("code"),
        "date_installation": sql.Identifier("date_installation")}

site = input("Site (ex. SN-CASA) : ")
tri = input("Trier par (code ou date_installation) : ").strip()

if tri not in TRIS:
    print("Tri refusé : choisissez code ou date_installation")
    raise SystemExit(1)

requete = sql.SQL("SELECT code, date_installation FROM ruche "
                  "WHERE site_id = %s ORDER BY {}").format(TRIS[tri])

try:
    with psycopg.connect(dbname="queenbee") as conn:
        for row in conn.execute(requete, (site,)):
            print(row)
except psycopg.Error:
    print("La recherche a échoué.")
