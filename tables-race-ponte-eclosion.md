# Race, temps de ponte, temps d'éclosion — tables concernées

Base : `arbiochemstandard_20261002_160451.dmp` — projet `AkohoReprise`.
Vérifié dans le dump (noms_quote de tables/colonnes/constraints) et dans
`arbiochem-ejb/src/java/ferme/` (entités + `setNomTable`).

> Vocabulaire du projet : la « race » s'appelle **SOUCHE** (terme avicole :
> la souche = la lignée génétique). Chaque **LOT** de volailles porte sa
> souche via `LOT.idSouche`.

---

## 1. La race (souche)

| Table physique | Rôle — pourquoi elle est concernée |
|---|---|
| `SOUCHE` | Référentiel des races. Table simple (`id/val`, style `TypeObjet`), PK `SOU...` via séquence `GETSEQSOUCHE` / `SEQ_SOUCHE`. Entité : `ferme.configuration.Souche`. C'est elle qu'on choisit quand on dit « telle race ». |
| `LOT` | Chaque lot (bande de volailles) porte `idSouche` (FK) + `idprogramme` + `idCategorieLot` + `datearrivee` + `dateeclosion` + `dateCloture`. Entité : `ferme.lot.Lot`. Sans le lot, impossible de savoir de quelle race vient un œuf ou un poussin. |
| `LOT_LIB` | Vue de lecture du lot (libellés). Lecture seule. |
| `CATEGORIELOT` | Référentiel des catégories de lot (lié par `FK_LOT_CATEGORIELOT`). |
| `PROGRAMMEZOOTECHNIQUE` | Programme d'élevage versionné (`code`, `version`, `daty`), lié à une souche (`idsouche`, FK `PROGZOOTECH_SOUCHE_FK`). C'est le « plan de conduite » propre à chaque race. |
| `PROGRAMMEZOOTECHNIQUEDETAILS` | **Normes par souche et par âge** : `pontehebdomadaire`, `pontecumulee`, `oeufcumule`, `poidsoeuf`, `fertilite`, `tauxeclosion`, `poussins`, `aliment`, `poids`, `mortalite`, `oacpourcentage`... C'est ici que le « temps de ponte » et le « temps d'éclosion » ATTENDUS d'une race sont chiffrés (courbe de ponte, taux d'éclosion de référence). |

**Pourquoi :** tout le raisonnement « race + durées » part de `SOUCHE` → se décline en normes (`PROGRAMMEZOOTECHNIQUE*`) → s'applique à des animaux réels (`LOT.idSouche`).

---

## 2. Le temps de ponte (réel + prévu)

| Table physique | Rôle — pourquoi elle est concernée |
|---|---|
| `PROGRAMMEZOOTECHNIQUEDETAILS` | Normes de ponte par âge : `PONTEHEBDOMADAIRE`, `PONTECUMULEE`, `OEUF...`. Le « prévu ». |
| `SUIVIJOURNALIER` / `SUIVIJOURNALIERDETAIL` | Suivi quotidien réel par bâtiment/parquet : âge jour, entrées, **tri**, mortalité, eau, températures... (`ferme.suiviJournalier`). Le « réel » comparé aux normes. Vues : `SUIVIJOURNALIER_LIB`, `SUIVIJOURNALIERDETAIL_LIB`. |
| `RECEPTIONOAC` / `RECEPTIONOACDETAIL` | Réception des Œufs À Couver au couvoir : `DATEPONTE`, `DATECOLLECTE`, `DATERECEPTION`, heures départ ferme / arrivée couvoir, températures véhicule. C'est le point où la ponte (date de ponte) entre dans la chaîne couvoir. Vues : `RECEPTIONOAC_LIB`, `...DETAIL_LIB`. |
| `MISEENINCUBATEURDETAIL` | Chaque mise en machine rappelle `DATEPONTE`, `QTE`, `POIDSMOYEN`, `IDLOT`, `IDBATIMENT`, `IDPARQUET`. Lien direct ponte → incubation. |
| `TRIAGEOEUF` / `TRIAGEOEUFDETAIL` (+ `QUALITETRIAGEOEUF`) | Tri des œufs avant incubation (écarte les non-incubables). |
| `MIRAGE` / `MIRAGEDETAIL` | Mirage (contrôle des œufs en cours d'incubation). |

**Pourquoi :** le temps de ponte se mesure entre `DATEPONTE` (réception OAC, mise en incubateur) et se pilote via les normes hebdomadaires/cumulées du programme zootechnique de la souche.

---

## 3. Le temps d'éclosion (réel + prévu)

| Table physique | Rôle — pourquoi elle est concernée |
|---|---|
| `MISEENINCUBATEUR` | Mise en machine : `datemiseenmachine`, **`dateeclosionprevue`**, `idincubateur`, `heuredebutincubation`, `heureprechauffage`, températures/humidité cibles. C'est ici que le « temps d'éclosion prévu » est calculé (mise en machine + durée d'incubation propre à la souche). Détail par lot : `MISEENINCUBATEURDETAIL`. Séquences : `GETSEQ_MISEENINCUBATEUR`, `GETSEQ_MISEENINCUBATEURDETAIL`. Vues : `MISEENINCUBATEUR_LIB`, `...DETAIL_LIB`. |
| `INCUBATEUR` | Référentiel des incubateurs (séquence `GETSEQINCUBATEUR`). |
| `ECLOSOIR` | Référentiel des éclosoirs (séquence `GETSEQECLOSOIR`). |
| `ECLOSION` | Éclosion réelle : `dateeclosion` (+ liens éclosoir/incubateur/lot/parquet). PK via `GETSEQ_ECLOSION`. Vue : `ECLOSION_LIB`. |
| `ECLOSIONDETAIL` | Détail de l'éclosion par lot/qualité (`ECLOSIONDET_QUAL_FK`). PK via `GETSEQ_ECLOSIONDETAIL`. Vue : `ECLOSIONDETAIL_LIB`. |
| `QUALITEECLOSION` | Référentiel des qualités d'éclosion (séquence `GETSEQ_QUALITEECLOSION`). |
| `TRIAGEQUALITEPOUSSIN` / `TRIAGEQUALITEPOUSSINDETAIL` | Tri qualité des poussins à la sortie (lié éclosoir/incubateur : `FK_TRIAGEPOUS_ECLOSOIR`, `FK_TRIAGEPOUS_INCUBATEUR`). |
| `LOT` | Porte `dateeclosion` : un lot naît d'une éclosion. |
| `SUIVICHAMBREFROIDE` / `SUIVICHAMBREFROIDEDETAIL` | Conservation des œufs en chambre froide avant incubation (délai qui influence l'éclosion). |

**Pourquoi :** le temps d'éclosion = `dateeclosion` (réelle, `ECLOSION`) − `datemiseenmachine` (prévue via `dateeclosionprevue`, `MISEENINCUBATEUR`), comparé au `tauxeclosion` de référence de la souche (`PROGRAMMEZOOTECHNIQUEDETAILS`).

---

## 4. Chaîne complète (pour situer)

```
SOUCHE ──► PROGRAMMEZOOTECHNIQUE(+DETAILS) : normes ponte/éclosion par race
  │
LOT (idSouche) ──► SUIVIJOURNALIER : ponte réelle quotidienne
  │
RECEPTIONOAC (DATEPONTE) ──► TRIAGEOEUF ──► MISEENINCUBATEUR (dateeclosionprevue)
  │
MIRAGE ──► ECLOSION (dateeclosion) ──► TRIAGEQUALITEPOUSSIN
  │
RECEPTIONPOUSSINAEROPORT (aéroport, HEUREARRIVEECOUVOIR, FK lot)
  │
TRANSFERTPOULET (FK lot) ──► TRIAGEBATIMENT / bâtiments ──► compartiments
```

Tables de liaison à retenir : `LOT.idSouche`, `MISEENINCUBATEURDETAIL.idlot`,
`ECLOSION*_lot/parquet/batiment (FK)`, `RECEPTIONPOUSSINAEROPORT*_lot`,
`TRANSFERTPOULET*_lot`.

## 5. Ce qui N'EST PAS concerné

- Vues `*_LIB`, `*_CPL` : lecture seule, jamais d'écriture.
- Tout le cycle achat (`AS_BONDECOMMANDE`, `AS_BONDELIVRAISON`,
  `FACTUREFOURNISSEUR`, `MODEPAIEMENT`, `MAGASIN2`...) : c'est l'amont
  (partie fournisseur), pas la biologie des races.
- `BATIMENT*VIDESANITAIRE*`, `FUMIGATION`, `VACCINATION`, `ALIMENT*`,
  `PESEE*`, `DISTRIBUTION*` : hygiène/santé/alimentation — utiles à
  l'élevage mais pas au triptyque race/ponte/éclosion.
