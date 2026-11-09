# query_vuln.py : VOLONTAIREMENT VULNÉRABLE à l'injection SQL (lab 3, ne pas réutiliser)
# Connexion : PGUSER / PGHOST dans le terminal, mot de passe lu dans pgpass.conf (jamais dans le code)
import psycopg

conn = psycopg.connect(dbname="queenbee")
code = input("Code ruche : ")
sql = "SELECT code, site_id FROM ruche WHERE code = '" + code + "'"
print("Requête envoyée :", sql)
for row in conn.execute(sql):
    print(row)
