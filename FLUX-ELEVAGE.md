# 🔄 FLUX ÉLEVAGE — SANS ALÉA

> De la commande des poussins à leur rangement dans les parquets.
> Chaque étape est dessinée **Page → Action → Métier → Base**, d'après le code actuel
> (`arbiochem-ejb/src/java/ferme/`, `arbiochem-war/web/pages/ferme/`, `sql/schema_elevage.sql`).
> Aucune valeur en Ar : on ne manipule que des quantités.

## Légende

```
┌──────────────┐   ┌──────────────┐   ┌──────────────────┐   ┌──────────────┐
│ 🖥️ PAGE (JSP) │──▶│ ⚡ ACTION     │──▶│ 🧠 MÉTIER (Java)  │──▶│ 🗃️ BASE       │
│ ce qu'on voit│   │ bouton / acte│   │ classe.méthode() │   │ table / vue  │
└──────────────┘   └──────────────┘   └──────────────────┘   └──────────────┘
```

| Action | JSP générique | Méthode appelée | Effet |
|---|---|---|---|
| Enregistrer / Modifier | `apresMultiple.jsp`, `acte=insert` | `createObject()` | mère + lignes, `etat = 1` (créé) |
| Valider | `apresTarif.jsp`, `acte=valider` | `validerObject()` | `etat = 11` (validé) |
| Supprimer | `apresTarif.jsp`, `acte=delete` | suppression | — |

> ⚠ Une étape ne voit que ce que l'étape précédente a **validé** (`etat >= 11`).
> « Modifier » repasse par `createObject()` : `ControlePoussin.preparerModification()` supprime
> d'abord les anciennes lignes (sinon APJ les doublerait) et refuse si le document est déjà validé.

---

## 🗺️ VUE D'ENSEMBLE

```
 ① BON DE COMMANDE            combien de poussins on a acheté
        │ idbc
        ▼
 ② RÉCEPTION AÉROPORT         − morts − perdus        → vivants aéroport
        │ idlot                (le BC est recopié sur le LOT à la validation)
        ▼
 ③ RÉCEPTION USINE            − morts − perdus        → vivants usine
        │ idlot                (trajet : véhicule, chauffeur, contrôleur)
        ▼
 ④ TRIAGE PAR PARQUET         vivants rangés : parquet × sexe × état de santé × qte
        │                      (le SEXE n'apparaît qu'ici)
        ▼
 ⑤ COMPTAGE                   mâles / femelles / malades / sains par parquet et par lot
```

**Les quantités d'une étape à l'autre :**

```
commandés ──(− morts − perdus aéroport)──▶ vivants aéroport
          ──(− morts − perdus usine)─────▶ vivants usine
          ──(répartis dans les parquets)─▶ réparti  ≤ vivants usine
                                             non répartis = vivants usine − réparti
```

**Le maillon entre toutes les étapes : le LOT.**

```
AS_BONDECOMMANDE ◀─idbc── RECEPTIONPOUSSINAEROPORT ──idlot──▶ LOT ◀──idlot── RECEPTIONUSINE
                                                               ▲
                                                               └──idlot── TRIAGEBATIMENTPARQUET
```

---

# ① BON DE COMMANDE

```
┌───────────────────────────────┐   ┌──────────────────────┐   ┌────────────────────────────┐   ┌─────────────────────────────┐
│ bondecommande/                │──▶│ apresMultiple.jsp    │──▶│ As_BonDeCommande           │──▶│ AS_BONDECOMMANDE            │
│ bondecommande-saisie.jsp      │   │ acte=insert          │   │  .createObject()           │   │ AS_BONDECOMMANDE_FILLE      │
│ fournisseur, date, lignes :   │   │                      │   │                            │   │  (produit, quantite, pu,    │
│ produit POUSSIN, qte, PU      │   │                      │   │                            │   │   montant)                  │
├───────────────────────────────┤   ├──────────────────────┤   ├────────────────────────────┤   ├─────────────────────────────┤
│ fiche → [Valider]             │──▶│ apresTarif.jsp       │──▶│  .validerObject()          │──▶│ etat = 11                   │
│                               │   │ acte=valider         │   │                            │   │                             │
└───────────────────────────────┘   └──────────────────────┘   └────────────────────────────┘   └─────────────────────────────┘
                                                                  lu ensuite via la vue v_bc_poussin :
                                                                  qtecommande = Σ quantite des lignes dont le produit
                                                                  contient « POUSSIN »   (classe ferme.utils.BcPoussin)
```

---

# ② RÉCEPTION AÉROPORT

> On ne saisit **que les pertes** (MORT / PERDU). Les vivants sont **calculés**.
> Pas de sexe ici : on ne connaît qu'un total.

```
┌──────────────────────────────────┐   ┌──────────────────────┐   ┌───────────────────────────────────────────────┐   ┌───────────────────────────────────┐
│ ferme/receptionaeroport/         │──▶│ apresMultiple.jsp    │──▶│ ReceptionPoussinAeroport.createObject()       │──▶│ RECEPTIONPOUSSINAEROPORT          │
│ receptionaeroport-saisie.jsp     │   │ acte=insert          │   │  ├ preparerModification()                     │   │  idlot, idbc, daty, heures,       │
│                                  │   │                      │   │  └ controler(lignes)                          │   │  qterecus = vivants (calculé)     │
│ En-tête : lot, bon de commande,  │   │                      │   │     ├ lot obligatoire                         │   │  etat = 1                         │
│  date, heure départ / arrivée,   │   │                      │   │     ├ ControlePoussin.checkBcPoussin          │   │ RECEPTIONPOUSSINAEROPORTDETAIL    │
│  cartons, remarque               │   │                      │   │     │   (BC existe, validé, a des poussins)   │   │  idqualitepoussin, qte            │
│ Lignes : Perte (mort / perdu)    │   │                      │   │     ├ checkBcDejaUtilise (1 BC = 1 réception) │   │  idsexe = null                    │
│          | quantité              │   │                      │   │     ├ checkLignePerte (MORT/PERDU, qte > 0)   │   │                                   │
│                                  │   │                      │   │     ├ checkSomme (pertes ≤ commandés)         │   │                                   │
│                                  │   │                      │   │     └ qterecus = commandés − pertes           │   │                                   │
├──────────────────────────────────┤   ├──────────────────────┤   ├───────────────────────────────────────────────┤   ├───────────────────────────────────┤
│ receptionaeroport-fiche.jsp      │──▶│ apresTarif.jsp       │──▶│ .validerObject()                              │──▶│ etat = 11                         │
│ [Valider]                        │   │ acte=valider         │   │  ├ recharge la réception en base              │   │ LOT.idbc = idbc                   │
│                                  │   │                      │   │  ├ controler() rejoué                         │   │                                   │
│                                  │   │                      │   │  └ lierBcAuLot() (refus si le lot a déjà      │   │                                   │
│                                  │   │                      │   │     un AUTRE bon de commande)                 │   │                                   │
├──────────────────────────────────┤   ├──────────────────────┤   ├───────────────────────────────────────────────┤   ├───────────────────────────────────┤
│ receptionaeroport-liste.jsp      │──▶│ (recherche APJ)      │──▶│ ReceptionPoussinAeroportLib                   │──▶│ vue RECEPTIONPOUSSINAEROPORT_LIB  │
│ commandés, morts, perdus, vivants│   │                      │   │                                               │   │  ← v_reception_aeroport_bilan     │
└──────────────────────────────────┘   └──────────────────────┘   └───────────────────────────────────────────────┘   └───────────────────────────────────┘
```

| Nomenclature | Valeur |
|---|---|
| `QUALITEPOUSSIN` MORT | `QP000022` (`ConstanteFerme.qualiteMort`) |
| `QUALITEPOUSSIN` PERDU | `QP000023` (`ConstanteFerme.qualitePerdu`) |
| Clés | `RPA` / `RPAF` |

---

# ③ RÉCEPTION USINE (le trajet aéroport → usine)

> Même principe : on saisit les pertes du trajet, les vivants sont calculés.
> Le transport (véhicule, chauffeur, contrôleur) est porté par cet écran.

```
┌──────────────────────────────────┐   ┌──────────────────────┐   ┌───────────────────────────────────────────────┐   ┌───────────────────────────────────┐
│ ferme/receptionusine/            │──▶│ apresMultiple.jsp    │──▶│ ReceptionUsine.createObject()                 │──▶│ RECEPTIONUSINE                    │
│ receptionusine-saisie.jsp        │   │ acte=insert          │   │  ├ preparerModification()                     │   │  idlot, daty, heures, idvehicule, │
│                                  │   │                      │   │  └ controler(lignes)                          │   │  idchauffeur, idcontroleur,       │
│ En-tête : lot, date, heures,     │   │                      │   │     ├ ControlePoussin.checkReceptionAeroport  │   │  qterecus = vivants (calculé)     │
│  véhicule, chauffeur,            │   │                      │   │     │   (réception aéroport VALIDÉE           │   │ RECEPTIONUSINEDETAIL              │
│  contrôleur, remarque            │   │                      │   │     │    → vivants aéroport)                  │   │  idqualitepoussin, qte            │
│ Lignes : Perte (mort / perdu)    │   │                      │   │     ├ checkLotDejaReceptionne                 │   │                                   │
│          | quantité              │   │                      │   │     │   (un lot passe une seule fois)         │   │                                   │
│                                  │   │                      │   │     ├ checkLignePerte                         │   │                                   │
│                                  │   │                      │   │     ├ checkSomme (pertes ≤ vivants aéroport)  │   │                                   │
│                                  │   │                      │   │     └ qterecus = vivants aéroport − pertes    │   │                                   │
├──────────────────────────────────┤   ├──────────────────────┤   ├───────────────────────────────────────────────┤   ├───────────────────────────────────┤
│ receptionusine-fiche.jsp         │──▶│ apresTarif.jsp       │──▶│ .validerObject() → controler() rejoué         │──▶│ etat = 11                         │
│ [Valider]                        │   │ acte=valider         │   │                                               │   │                                   │
├──────────────────────────────────┤   ├──────────────────────┤   ├───────────────────────────────────────────────┤   ├───────────────────────────────────┤
│ receptionusine-liste.jsp         │──▶│ (recherche APJ)      │──▶│ ReceptionUsineLib                             │──▶│ vue RECEPTIONUSINE_LIB            │
│ attendus, morts, perdus, vivants │   │                      │   │                                               │   │  ← v_reception_usine_bilan        │
└──────────────────────────────────┘   └──────────────────────┘   └───────────────────────────────────────────────┘   └───────────────────────────────────┘
```

Clés : `RUI` / `RUIF`.

---

# ④ TRIAGE PAR PARQUET (répartition en compartiments)

> Uniquement des **vivants** (`idqualite` forcé à `QP000001`, conforme).
> C'est ici que le **sexe** apparaît. **Le bâtiment est ignoré** : un compartiment = un parquet.
> État de santé : **10 = sain**, **1 à 9 = malade** (plus de mort au triage).

## 4.1 Saisie

```
┌──────────────────────────────────┐   ┌──────────────────────┐   ┌───────────────────────────────────────────────┐   ┌───────────────────────────────────┐
│ ferme/triagebatiment/            │   │                      │   │ TriageBatimentParquet                         │   │                                   │
│ triagebatimentparquet-saisie.jsp │   │                      │   │                                               │   │                                   │
│                                  │   │ (ouverture de la     │   │ getDispoLot(idLot) → calculerDispo()          │   │ RECEPTIONUSINE_LIB (vivants)      │
│ En-tête : lot, date,             │ ─▶│  page avec idLot)    │──▶│  = checkReceptionUsine(lot)                   │──▶│ TRIAGEBATIMENTPARQUET(+DETAIL)    │
│  « Vivants disponibles » (RO)    │   │                      │   │    − getDejaReparti()                         │   │  (autres triages validés du lot)  │
│                                  │   │                      │   │                                               │   │                                   │
│ Lignes (10) :                    │──▶│ apresMultiple.jsp    │──▶│ .createObject()                               │──▶│ TRIAGEBATIMENTPARQUET             │
│  Parquet | Capacité max | Sexe | │   │ acte=insert          │   │  ├ preparerModification()                     │   │  idlot, daty, dispo, etat = 1     │
│  Quantité | État de santé |      │   │                      │   │  └ controler(lignes)                          │   │ TRIAGEBATIMENTPARQUETDETAIL       │
│  Remarque                        │   │                      │   │     ├ lot obligatoire                         │   │  idparquet, capmax, idsexe, qte,  │
│                                  │   │                      │   │     ├ calculerDispo()                         │   │  etatsante, remarque,             │
│ (bâtiment et qualité cachés)     │   │                      │   │     ├ checkLigne() pour chaque ligne :        │   │  idqualite = QP000001             │
│                                  │   │                      │   │     │   parquet, capmax > 0, sexe M/F,        │   │                                   │
│                                  │   │                      │   │     │   santé 1..10, qte > 0                  │   │                                   │
│                                  │   │                      │   │     ├ 1 parquet = 1 seule capacité max        │   │                                   │
│                                  │   │                      │   │     ├ par parquet :                           │   │                                   │
│                                  │   │                      │   │     │  ├ ControlePoussin.checkParquet         │   │                                   │
│                                  │   │                      │   │     │  │  (aucun AUTRE lot dans le parquet)   │   │                                   │
│                                  │   │                      │   │     │  └ ControlePoussin.checkCapParquet      │   │                                   │
│                                  │   │                      │   │     │     (déjà occupé + ajouté ≤ capmax)     │   │                                   │
│                                  │   │                      │   │     └ ControlePoussin.checkSomme              │   │                                   │
│                                  │   │                      │   │        (total ≤ vivants usine − déjà réparti) │   │                                   │
└──────────────────────────────────┘   └──────────────────────┘   └───────────────────────────────────────────────┘   └───────────────────────────────────┘
```

## 4.2 Validation

```
┌──────────────────────────────────┐   ┌──────────────────────┐   ┌───────────────────────────────────────────────┐   ┌───────────────────────────────────┐
│ triagebatimentparquet-fiche.jsp  │──▶│ apresTarif.jsp       │──▶│ TriageBatimentParquet.validerObject()         │──▶│ TRIAGEBATIMENTPARQUET.etat = 11   │
│ [Valider] [Modifier] [Supprimer] │   │ acte=valider         │   │  ├ recharge le triage en base                 │   │                                   │
│ (visibles tant que etat < 11)    │   │                      │   │  └ controler() rejoué sur les lignes en base  │   │                                   │
│                                  │   │                      │   │    (un autre triage a pu remplir le parquet   │   │                                   │
│                                  │   │                      │   │     entre la saisie et la validation)         │   │                                   │
└──────────────────────────────────┘   └──────────────────────┘   └───────────────────────────────────────────────┘   └───────────────────────────────────┘
```

## 4.3 Consultation

```
┌──────────────────────────────────┐   ┌──────────────────────┐   ┌───────────────────────────────────────────────┐   ┌───────────────────────────────────┐
│ triagebatimentparquet-liste.jsp  │──▶│ (recherche APJ)      │──▶│ TriageBatimentParquetLib (PageRecherche)      │──▶│ vue TRIAGEBATIMENTPARQUET_LIB     │
│ Id | Lot | Souche | Date |       │   │ filtres : lot,       │   │                                               │   │  dispo                            │
│ Vivants dispo | Non répartis |   │   │ souche, dates        │   │                                               │   │  ecart = dispo − Σ qte du triage  │
│ État                             │   │                      │   │                                               │   │                                   │
├──────────────────────────────────┤   ├──────────────────────┤   ├───────────────────────────────────────────────┤   ├───────────────────────────────────┤
│ triagebatimentparquet-fiche.jsp  │──▶│ (consultation)       │──▶│ TriageBatimentParquetLib (PageConsulte)       │──▶│ vue TRIAGEBATIMENTPARQUET_LIB     │
│  └ onglet Détails                │──▶│ idmere = triage      │──▶│ TriageBatimentParquetDetailLib                │──▶│ vue TRIAGEBATPARQUETDETAIL_LIB    │
│    Parquet | Capmax | Sexe |     │   │                      │   │                                               │   │  (libellés parquet, sexe,         │
│    État de santé | Qté | Remarque│   │                      │   │                                               │   │   état de santé)                  │
└──────────────────────────────────┘   └──────────────────────┘   └───────────────────────────────────────────────┘   └───────────────────────────────────┘
```

### Exemple

```
Commandés 1 000 → aéroport : 30 morts, 10 perdus → 960 vivants
               → usine     : 15 morts,  5 perdus → 940 vivants (= « Vivants disponibles »)

Triage TB-001 :
Parquet | Capacité max | Sexe    | Quantité | État de santé
P1      | 500          | Mâle    | 450      | Sain (10)
P2      | 500          | Femelle | 470      | Sain (10)
P3      |  50          | Mâle    |  12      | Malade (5)     ← parquet « quarantaine »
                                  ─────
                                   932      Non répartis = 940 − 932 = 8
```

---

# ⑤ COMPTAGE (vues de lecture, triages validés)

```
TRIAGEBATIMENTPARQUETDETAIL + TRIAGEBATIMENTPARQUET
        │
        ▼
 v_compte_triage    1 triage × parquet : nbmale, nbfemelle, nbmalade (1..9), nbsain (10), nbtotal
        │  (etat >= 11)
        ▼
 v_compte_parquet   1 lot × parquet
        │
        ▼
 v_compte_lot       1 lot (tous parquets)

 v_parquet_occupation   capacité / occupé / reste / lot présent par parquet
```

---

# 📊 RÉCAPITULATIF

| # | Étape | Page de saisie | Classe | Tables | Vues | Contrôles |
|---|---|---|---|---|---|---|
| ① | Bon de commande | `bondecommande-saisie.jsp` | `As_BonDeCommande` | `AS_BONDECOMMANDE` (+`_FILLE`) | `v_bc_poussin` | validation BC |
| ② | Réception aéroport | `receptionaeroport-saisie.jsp` | `ReceptionPoussinAeroport` | `RECEPTIONPOUSSINAEROPORT` (+`DETAIL`) | `v_reception_aeroport_bilan`, `..._LIB` | `checkBcPoussin`, `checkBcDejaUtilise`, `checkLignePerte`, `checkSomme`, `lierBcAuLot` |
| ③ | Réception usine | `receptionusine-saisie.jsp` | `ReceptionUsine` | `RECEPTIONUSINE` (+`DETAIL`) | `v_reception_usine_bilan`, `..._LIB` | `checkReceptionAeroport`, `checkLotDejaReceptionne`, `checkLignePerte`, `checkSomme` |
| ④ | Triage par parquet | `triagebatimentparquet-saisie.jsp` | `TriageBatimentParquet` | `TRIAGEBATIMENTPARQUET` (+`DETAIL`) | `TRIAGEBATIMENTPARQUET_LIB`, `TRIAGEBATPARQUETDETAIL_LIB` | `checkReceptionUsine`, `checkLigne`, `checkParquet`, `checkCapParquet`, `checkSomme` |
| ⑤ | Comptage | — | — | — | `v_compte_triage/parquet/lot`, `v_parquet_occupation` | — |

**Tous les contrôles communs** sont dans `ferme/utils/ControlePoussin.java`.

## Nomenclatures

| Table | Classe | Contenu |
|---|---|---|
| `LOT` | `ferme.lot.Lot` | les lots (+ `idbc` posé à la réception aéroport) |
| `PARQUET` | `ferme.configuration.Parquet` | les compartiments |
| `QUALITEPOUSSIN` | `ferme.configuration.QualitePoussin` | Conforme `QP000001`, Mort `QP000022`, Perdu `QP000023` |
| `ETATSANTE` | `bean.TypeObjet` | 1..9 malade, 10 sain |
| `SEXE` | `bean.TypeObjet` | `1` mâle, `0` femelle |

## Points d'attention

1. **L'ordre de validation compte** : pas de réception usine sans réception aéroport validée,
   pas de triage sans réception usine validée.
2. **Un BC ↔ une réception aéroport**, **un lot ↔ une réception usine**, **un parquet ↔ un seul lot**.
3. La capacité max d'un parquet est **saisie au triage** (`capmax`), pas lue dans le bâtiment.
4. Les **malades** restent dans le parquet où on les met : pour une quarantaine, créer un parquet
   dédié (`ferme/configuration/parquet-saisie.jsp`) et y trier les lignes de santé 1..9.
