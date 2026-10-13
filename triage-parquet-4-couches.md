# Insérer les animaux d'un lot dans un parquet — les 4 couches

Cas : `ferme/triagebatiment/` — on prend un LOT (qui, quelle souche) et on le
répartit en PARQUETs (où), par sexe/qualité/quantité.

```
AFFICHAGE (JSP)  ──POST──►  ACTION (apresMultiple)  ──►  MÉTIER (EJB)
                                                                    │
                                                                    ▼
                                                              BASE (Oracle)
```

---

## 1. Workflow complet d'une insertion (numéros = ordre réel)

1. **AFFICHAGE — saisie** : `ferme/triagebatiment/triagebatimentparquet-saisie.jsp`
   ouvre avec `?idLot=LOT...` (ou choix manuel du lot via autocomplete
   `ferme.lot.Lot` sur `LOT`).
2. La page calcule les **disponibles** du lot : `mere.getDisponnibleLib(idLot,
   sexe, qualiteConforme)` → lit la **vue** `v_qte_dispo_lot_sexe_qualite`
   (via `TriageLotSexeQualite`), pré-remplit `dispomale` / `dispofemelle`
   en `readonly`.
3. L'utilisateur remplit le tableau (10 lignes) : **bâtiment → parquet**
   (liste dépendante : le parquet se filtre selon le bâtiment),
   **sexe** (`SEXE`), **qualité** (`QUALITEPOUSSIN`), **qte**.
4. POST vers `ACTION` : `apresMultiple.jsp` avec hidden
   `acte=insert`, `classe=ferme.triageBatiment.TriageBatimentParquet`,
   `classefille=...TriageBatimentParquetDetail`,
   `colonneMere=idmere`, `nomtable=TRIAGEBATIMENTPARQUETDETAIL`,
   `bute=...triagebatimentparquet-fiche.jsp`.
5. **ACTION** : branche `acte=insert` → `PageInsertMultiple` lit la requête,
   `getObjectAvecValeur()` (mère) + `getObjectFilleAvecValeur()` (lignes),
   force `nomtable` sur les filles, appelle
   `u.createObjectMultiple(mere, "idmere", filles)`.
6. **MÉTIER** : `TriageBatimentParquet.construirePK` génère l'id (`TB...`
   via `getseq_triagebatimentparquet`), `super.createObject` INSERT la mère,
   puis chaque fille (`TBD...` via `getseq_triagebatparquetdetail`) avec
   `idmere` = id de la mère. Contrôle quantités mâle/femelle existe mais
   est **commenté** (lignes 93-121) → aucun contrôle actif aujourd'hui.
7. **BASE** : 1 ligne `TRIAGEBATIMENTPARQUET` + N lignes
   `TRIAGEBATIMENTPARQUETDETAIL`. La fiche (`...-fiche.jsp`, `PageConsulte`
   sur `TRIAGEBATIMENTPARQUET_LIB`) affiche mère + onglet détails, boutons
   Valider / Modifier / Supprimer (`etat < 11`).

---

## 2. Couche AFFICHAGE — `web/pages/ferme/triagebatiment/`

| Fichier | Rôle |
|---|---|
| `triagebatimentparquet-saisie.jsp` | Formulaire mère (date, lot, dispos) + tableau 10 lignes (bâtiment/parquet/sexe/qualité/qte). Sert aussi en `acte=update`. |
| `triagebatimentparquet-liste.jsp` | `PageRecherche` des tris (à vérifier : titre/filtres). |
| `triagebatimentparquet-fiche.jsp` | `PageConsulte` sur `TRIAGEBATIMENTPARQUET_LIB` : lot + souche (`IdSoucheLib`), écarts mâle/femelle, lien clic vers `lot-fiche.jsp:25`, onglets détails, Valider/Modifier/Supprimer. |
| `inc/triagebatimentparquet-det.jsp` | Détail des lignes de la fiche. |

Référentiels lus par la saisie (listes déroulantes, **lecture seule**) :
`LOT` (choix du lot), `v_qte_dispo_lot_sexe_qualite` (disponibles),
`BATIMENT`, `PARQUET_BATIMENT_LIB` (parquets filtrés par bâtiment),
`SEXE`, `QUALITEPOUSSIN`.

### ✅ TOUCHABLE (affichage)
- Libellés (`setLibelle`), ordre des colonnes (`setColOrdre:75`),
  nombre de lignes (`taille=10:29`), champs visibles/cachés.
- Listes déroulantes (ajouter un filtre `setApresW`, ex. parquets actifs).
- Pré-remplissage depuis `?idLot=` (lignes 41-50) : ajouter d'autres
  `setDefaut` (ex. date du jour).
- Ajouter un contrôle JS côté formulaire (ex. somme des qte ≤ dispo).

### ❌ INTOUCHABLE (affichage)
- Les hidden du POST (`acte/classe/classefille/colonneMere/nomtable/
  bute/nombreLigne`) : si tu les renommes ou changes leurs valeurs, l'ACTION
  ne sait plus quoi insérer → erreur ou mauvaise table.
- `colonneMere=idmere` : c'est la soudure mère/filles. Ne pas changer.
- Ne jamais écrire du SQL dans la JSP : toute lecture passe par les
  classes métier (`getDisponnibleLib`, listes APJ).

---

## 3. Couche ACTION — `web/pages/apresMultiple.jsp`

Page **générique et partagée** par tout le projet (BC, BL, tri, factures...).
Branche `acte=insert` (lignes ~134-150 du fichier commenté) :
`PageInsertMultiple` → `getObjectAvecValeur()` /
`getObjectFilleAvecValeur()` → `createObjectMultiple(mere, colonneMere,
filles)` → redirection `bute&id=...`.

### ✅ TOUCHABLE (action)
- **Rien, en pratique.** Si le tri a besoin d'un comportement spécial,
  on ne modifie PAS `apresMultiple.jsp` : on met la logique dans le
  métier (`createObject` de l'entité) ou on crée une page d'action
  dédiée (comme `apresMvtStock.jsp` pour les BL).

### ❌ INTOUCHABLE (action)
- Tout le fichier : une modification ici casse **toutes** les saisies
  du projet, pas seulement le tri. Lire seulement.

---

## 4. Couche MÉTIER — `arbiochem-ejb/src/java/ferme/triageBatiment/`

| Classe | Rôle |
|---|---|
| `TriageBatimentParquet` | Mère : `id, daty, idlot, dispomale, dispofemelle, etat`. Table `TRIAGEBATIMENTPARQUET:70`, liaison filles `idmere:72`, PK `TB...` (`getseq_triagebatimentparquet:77`). |
| `TriageBatimentParquetDetail` | Fille : `id, idmere, idbatiment, idparquet, idsexe, idqualite, qte`. Table `TRIAGEBATIMENTPARQUETDETAIL:83`, PK `TBD...` (`getseq_triagebatparquetdetail:90`). |
| `TriageBatimentParquetLib` / `...DetailLib` | Vues de lecture pour fiche + listes (`TRIAGEBATIMENTPARQUET_LIB`, écarts). |
| `TriageLotSexeQualite(Lib)` | Vue `v_qte_dispo_lot_sexe_qualite` : stock disponible par (lot, sexe, qualité). Source des `dispomale/dispofemelle`. |
| `ferme.utils.ConstanteFerme` | Constantes (`IDSEXEMALE`, `IDSEXEFEMELLE`, `qualiteConforme`). |

### ✅ TOUCHABLE (métier)
- **Réactiver le contrôle des quantités** : décommenter/adapter
  `createObject` lignes 93-121 (somme lignes mâles = `dispomale`, idem
  femelles) — c'est LA règle « on ne trie pas plus que le dispo ».
- Ajouter des contrôles : lot existant et non clôturé, `qte > 0`,
  parquet actif, `daty` cohérente avec le lot.
- `getDisponnible / getDisponnibleLib:125-173` : changer la source du
  dispo si la règle évolue (ex. autre qualité que `qualiteConforme`).
- Getters/setters, libellés : sans risque.

### ❌ INTOUCHABLE (métier)
- `getNomTable`, `liaisonFille`, `attributIDName`, préfixes PK (`TB`,
  `TBD`) : ce sont les soudures avec la base et l'ACTION.
- Ne pas supprimer `super.createObject(u, c)` à la fin du `createObject`
  surchargé : c'est lui qui INSERT vraiment.
- Ne pas changer la signature des méthodes appelées par les JSP
  (`getDisponnibleLib`, `construirePK`...).

---

## 5. Couche BASE — dump `arbiochemstandard_20261002_160451.dmp`

```sql
-- DDL réel extrait du dump :
CREATE TABLE "TRIAGEBATIMENTPARQUET"
  ("ID" VARCHAR2(100), "DATY" DATE, "IDLOT" VARCHAR2(100),
   "DISPOMALE" NUMBER, "DISPOFEMELLE" NUMBER, "ETAT" NUMBER(*,0));

CREATE TABLE "TRIAGEBATIMENTPARQUETDETAIL"
  ("ID" VARCHAR2(100), "IDMERE" VARCHAR2(100),
   "IDBATIMENT" VARCHAR2(100), "IDPARQUET" VARCHAR2(100),
   "IDSEXE" VARCHAR2(100), "IDQUALITE" VARCHAR2(100), "QTE" NUMBER);
```

- **PK** : `ID` des deux tables. **Liaison** : `DETAIL.IDMERE` → mère.
- **FK nommées** : `FK_TRIAGEDETAIL_BATIMENT/_MERE/_PARQUET/_QUALITE`,
  côté lot : `FK_TRIAGEPOUS_LOT` (+ `FK_TRANSFPOULET_LOT`,
  `FK_RECPOUSS_LOT` pour les autres étapes).
- **Séquences** : `getseq_triagebatimentparquet` (mère `TB...`),
  `getseq_triagebatparquetdetail` (filles `TBD...`).
- **Vues lues** : `TRIAGEBATIMENTPARQUET_LIB`,
  `v_qte_dispo_lot_sexe_qualite`. **Référentiels** : `LOT`, `PARQUET`,
  `BATIMENT`, `SEXE`, `QUALITEPOUSSIN`, `SOUCHE`.

### ✅ TOUCHABLE (base)
- **Par SQL métier uniquement** (via les entités) : INSERT/SELECT.
- Ajouter un **index** si une lecture est lente (ex. sur `IDMERE`).

### ❌ INTOUCHABLE (base)
- Pas de `ALTER TABLE` / `DROP` à la main : DDL, PK, FK, séquences =
  contrat partagé avec le métier. Toute évolution passe par une
  migration + mise à jour de l'entité Java en même temps.
- Ne jamais écrire directement dedans pour « corriger » : passer par
  la fiche (Modifier) ou un script tracé.

---

## 6. Si on me demande de toucher une couche — mode d'emploi

| On me demande... | Fichiers à toucher | Comment |
|---|---|---|
| Changer le formulaire (libellé, colonne, nb lignes, liste) | `triagebatimentparquet-saisie.jsp` seul | `setLibelle`, `setColOrdre`, `taille`, `setApresW`. Tester : recharger, vérifier le POST dans l'onglet Réseau. |
| Ajouter un contrôle avant insert (ex. qte ≤ dispo) | `TriageBatimentParquet.createObject` (métier) | Décommenter/écrire le test, `throw new Exception("message clair")` → la JSP affiche l'alerte et fait `history.back()`. Vérifier dans `server.log`. |
| Changer la règle du « disponible » | `getDisponnibleLib` + vue `v_qte_dispo_lot_sexe_qualite` | D'abord la vue SQL, ensuite la méthode. Jamais l'un sans l'autre. |
| Ajouter une colonne (ex. remarque ligne) | **Base + métier + affichage, dans cet ordre** | 1) migration `ALTER TABLE ...DETAIL ADD`, 2) champ + getter/setter dans `TriageBatimentParquetDetail`, 3) `setColOrdre`/libellé dans la saisie. Tester insert → fiche. |
| Changer la redirection / l'action | Hidden `bute` de la saisie (affichage) | Pointe vers une autre fiche/liste. Ne pas toucher `apresMultiple.jsp`. |
| Valider/supprimer un tri | Rien à coder : boutons fiche → `apresTarif.jsp` (`valider`/`delete`) | Vérifier `etat` et `classe` dans l'URL du bouton. |
| Déboguer un insert qui échoue | `server.log` (WildFly) + alerte navigateur | `e.printStackTrace()` va dans `server.log` ; la JSP montre `alert(message)` + `history.back()`. Chercher `NullPointer` (champ mal nommé) ou violation FK (id lot/parquet inexistant). |
