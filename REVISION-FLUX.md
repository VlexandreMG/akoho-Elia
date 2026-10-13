# 🌙 RÉVISION EN UNE NUIT — Flux élevage (sans aléa)

> Lis dans l'ordre. Chaque partie fait 10–15 min. À la fin, fais le quiz **sans regarder**.
> Détails complets : `FLUX-ELEVAGE.md`.

---

## ⏱️ PARTIE 1 — L'histoire en 1 phrase (5 min)

> **On achète des poussins, on en perd à l'aéroport, on en perd sur la route vers l'usine,
> et on range les survivants dans des parquets.**

```
   ACHAT  ──▶  AÉROPORT  ──▶  USINE  ──▶  PARQUETS
   (BC)        − pertes       − pertes    (triage)
```

### 🧠 Moyen mnémotechnique : **« B-A-U-T »** (comme « beau-T »)

| Lettre | Étape | Ce qu'on saisit | Ce qu'on calcule |
|---|---|---|---|
| **B** | **B**on de commande | combien on achète | — |
| **A** | réception **A**éroport | morts + perdus | vivants = commandés − pertes |
| **U** | réception **U**sine | morts + perdus | vivants = vivants aéroport − pertes |
| **T** | **T**riage par parquet | parquet, sexe, santé, qté | non répartis = vivants usine − réparti |

### 🔑 Les 3 phrases à savoir par cœur

1. **On ne saisit jamais les vivants : on saisit les PERTES, les vivants sont CALCULÉS.**
2. **Le SEXE n'apparaît qu'au TRIAGE** (avant, on ne connaît qu'un total).
3. **Une étape n'est visible par la suivante que si elle est VALIDÉE (état 11).**

---

## ⏱️ PARTIE 2 — Le schéma unique à savoir dessiner (15 min)

Chaque étape fonctionne **pareil**. Retiens ce schéma une fois, il vaut pour tout :

```
  PAGE  ───────────▶  ACTION  ─────────────▶  MÉTIER  ──────────────▶  BASE
  xxx-saisie.jsp      apresMultiple.jsp       Classe.createObject()     TABLE + TABLEDETAIL
                      (acte=insert)            └ controler()            etat = 1 (créé)

  xxx-fiche.jsp       apresTarif.jsp          Classe.validerObject()    etat = 11 (validé)
  [Valider]           (acte=valider)           └ controler() REJOUÉ

  xxx-liste.jsp       recherche APJ           ClasseLib                 VUE xxx_LIB
```

🧠 **« Saisie → insert → create ; Fiche → valider → valider »**

### Remplis les trous pour chaque étape

| Étape | Page | Classe | Table |
|---|---|---|---|
| B | `bondecommande-saisie.jsp` | `As_BonDeCommande` | `AS_BONDECOMMANDE(_FILLE)` |
| A | `receptionaeroport-saisie.jsp` | `ReceptionPoussinAeroport` | `RECEPTIONPOUSSINAEROPORT(DETAIL)` |
| U | `receptionusine-saisie.jsp` | `ReceptionUsine` | `RECEPTIONUSINE(DETAIL)` |
| T | `triagebatimentparquet-saisie.jsp` | `TriageBatimentParquet` | `TRIAGEBATIMENTPARQUET(DETAIL)` |

🧠 Le nom de la page = le nom de la classe en minuscules. La table = le nom de la classe en majuscules.

---

## ⏱️ PARTIE 3 — Les contrôles (15 min)

Tous sont dans **`ControlePoussin.java`**. Il n'y en a que **4 idées** :

| Idée | Méthode | Phrase à dire |
|---|---|---|
| **1. L'étape d'avant existe et est validée** | `checkBcPoussin`, `checkReceptionAeroport`, `checkReceptionUsine` | « Pas d'usine sans aéroport validé » |
| **2. On ne perd pas plus que ce qu'on a** | `checkSomme` | « pertes ≤ ce qui est arrivé » |
| **3. Une perte = MORT ou PERDU** | `checkLignePerte` | « qualité QP000022 ou QP000023, qté > 0 » |
| **4. Le parquet est respecté** | `checkParquet`, `checkCapParquet` | « un seul lot par parquet, pas plus que la capacité max » |

### Les « une seule fois »

- 1 bon de commande → 1 seule réception aéroport (`checkBcDejaUtilise`)
- 1 lot → 1 seule réception usine (`checkLotDejaReceptionne`)
- 1 parquet → 1 seul lot (`checkParquet`)

### Le contrôle du triage, en une ligne

```
Σ quantités du triage  ≤  vivants usine − déjà réparti par les autres triages validés
```

### Le truc qui relie tout : le LOT

```
À la VALIDATION de la réception aéroport :  LOT.idbc = idbc   (lierBcAuLot)
```
➡️ Un lot sait de quel bon de commande il vient ; refus si le lot a déjà un **autre** BC.

---

## ⏱️ PARTIE 4 — Les codes à connaître (5 min)

| Quoi | Code |
|---|---|
| Créé / Validé | `1` / `11` |
| Conforme (vivant) | `QP000001` |
| Mort | `QP000022` |
| Perdu | `QP000023` |
| Mâle / Femelle | `1` / `0` |
| État de santé | `10` = sain, `1..9` = malade |

🧠 « **22 mort, 23 perdu** » (le mort vient avant le perdu). « **1 mâle** : le 1 est debout. »

---

## ✅ QUIZ (cache les réponses)

1. Dans quel ordre se font les étapes ?
2. À la réception aéroport, est-ce qu'on saisit les vivants ?
3. À quelle étape apparaît le sexe ?
4. Quelle méthode métier est appelée quand on clique sur Enregistrer ? Et sur Valider ?
5. Pourquoi un triage peut-il être refusé à la validation alors qu'il avait été accepté à la saisie ?
6. Où est posé `LOT.idbc` et à quoi sert-il ?
7. Combien de lots peut contenir un parquet ?

<details>
<summary>Réponses</summary>

1. Bon de commande → réception aéroport → réception usine → triage (**B-A-U-T**).
2. Non : on saisit les morts et les perdus, les vivants sont calculés (`qterecus`).
3. Au triage.
4. `createObject()` (via `apresMultiple.jsp`) ; `validerObject()` (via `apresTarif.jsp`).
5. `validerObject()` rejoue `controler()` sur la base : un autre triage validé entre-temps a pu remplir le parquet ou consommer le disponible.
6. À la validation de la réception aéroport (`lierBcAuLot`). Il relie le lot à son bon de commande (un lot ↔ un seul BC).
7. Un seul (`checkParquet`).

</details>

---

## 🗓️ Plan de la nuit

| Heure | Quoi |
|---|---|
| 0:00 | Parties 1 + 2 → redessine B-A-U-T et le schéma Page/Action/Métier/Base de mémoire |
| 0:30 | Partie 3 → récite les 4 idées de contrôle |
| 0:50 | Partie 4 + quiz |
| 1:05 | Relis seulement les lignes 🧠 |
| Au réveil | Quiz une seconde fois |
