"""recherche_vuln.py : version vulnérable (le tri est recopié dans la requête)."""
import psycopg

site = input("Site (ex. SN-CASA) : ")
tri = input("Trier par (code ou date_installation) : ")

sql = ("SELECT code, date_installation FROM ruche "
       "WHERE site_id = %s ORDER BY " + tri)

with psycopg.connect(dbname="queenbee") as conn:
    try:
        for row in conn.execute(sql, (site,)):
            print(row)
    except psycopg.Error as e:
        print("Erreur :", e)
