# Leçon 3, partie 2 : `vente.getMontantreste()`, c'est quoi et comment ça marche

> Objectif : comprendre d'où vient le nombre utilisé à l'étape 4 de `Vente.getMontantAPayerApresAvoir(...)` :
>
> ```java
> return Math.max(0, vente.getMontantreste() - avoir);
> ```

## Comment j'ai obtenu ces informations

- J'ai lu le getter dans [VenteLib.java](../../arbiochem-ejb/src/java/vente/VenteLib.java).
- J'ai demandé à Oracle le **texte** des vues concernées (`select text from user_views where view_name = '...'`) : `VENTE_CPL`, puis les vues qu'elle utilise (`VENTEMONTANTLEGER`, `LIAISONPAIEMENTTOTAL`, `AVOIRFCMONTANT_GBVENTE`, `AVOIRFCMONTANT`).
- J'ai lancé des requêtes en **lecture seule** pour avoir de vrais exemples. Les résultats sont recopiés plus bas.

---

## En une phrase

`getMontantreste()` renvoie **ce que le client doit encore** sur cette vente. Le calcul ne se fait **pas en Java** : c'est Oracle qui le fait, dans la vue `VENTE_CPL`. Java ne fait que **recopier** le résultat.

---

## 1. Côté Java : un simple getter

Dans [VenteLib.java](../../arbiochem-ejb/src/java/vente/VenteLib.java) :

```java
private double montantreste;            // ligne 51 : l'attribut

public void setMontantreste(double montantreste) {   // ligne 215 : le setter
    this.montantreste = montantreste;
}

public double getMontantreste() {       // ligne 219 : le getter
    return montantreste;
}
```

- **`montantreste`** : un attribut `private` de type `double`. Il contient un nombre, c'est tout.
- **`getMontantreste()`** : il **renvoie** ce nombre. Il ne fait **aucun calcul** et ne lit pas la base.
- **`setMontantreste(...)`** : il **range** un nombre dans l'attribut.

Cet attribut n'existe que dans `VenteLib`, pas dans `Vente`. C'est pour ça que j'ai relu la vente avec `new VenteLib()` (voir [01_cast_heritage_math_max.md](01_cast_heritage_math_max.md), partie 2).

### Qui remplit l'attribut ?

Personne ne l'écrit à la main. C'est le framework, au moment de la ligne :

```java
VenteLib vente = (VenteLib) new VenteLib().getById(this.getId(), "", c);
```

1. `getById` appelle `CGenUtil.rechercher`, qui exécute `select * from VENTE_CPL where id = '...'`.
2. Oracle renvoie une ligne, avec une colonne **`MONTANTRESTE`**.
3. `CGenUtil` voit la colonne `MONTANTRESTE` et cherche dans `VenteLib` l'attribut **du même nom** : `montantreste`. Il y recopie la valeur. C'est la **règle d'or 6** de la [leçon 2](../lecon2/01_lire_en_base.md) : colonne de la vue = attribut Java, même nom.
4. Ensuite, `vente.getMontantreste()` renvoie simplement cette valeur.

**Conséquence :** si je fais `new VenteLib()` sans lire la base, `getMontantreste()` renvoie **`0`** (la valeur par défaut d'un `double` en Java). Il faut **toujours** passer par `getById` ou `rechercher` pour que la valeur soit remplie.

---

## 2. Côté base : la formule dans `VENTE_CPL`

Voici la ligne de la vue `VENTE_CPL` qui fabrique la colonne :

```sql
CAST(NVL(V2.MONTANTTTC, 0) - NVL(MV.MONTANT, 0) -
     NVL(ACG.MONTANTTTCAR - ACG.MONTANTPAYEAR, 0) AS NUMBER(30, 5))   AS MONTANTRESTE
```

En français :

```
reste à payer = montant TTC de la vente
              - ce qui a déjà été payé
              - (avoirs faits sur cette vente - partie de ces avoirs déjà utilisée)
```

Les trois morceaux viennent de trois autres vues, reliées à la vente par des jointures :

```sql
FROM VENTE V
     JOIN      VENTEMONTANTLEGER      V2  ON V2.ID       = V.ID
     LEFT JOIN LIAISONPAIEMENTTOTAL   MV  ON MV.ID2      = V.ID
     LEFT JOIN AVOIRFCMONTANT_GBVENTE ACG ON ACG.IDVENTE = V.ID
```

### Morceau 1 : `V2.MONTANTTTC`, le montant TTC de la vente

Il vient de la vue **`VENTEMONTANTLEGER`**. Elle additionne les **lignes** de la vente (`VENTE_DETAILS`) : quantité × prix unitaire, moins les remises, moins les frais, plus la TVA. Le montant TTC n'est donc **stocké nulle part** : il est recalculé à partir des détails chaque fois qu'on lit la vue.

- `JOIN` (et pas `LEFT JOIN`) : une vente **sans aucune ligne de détail** n'apparaît **pas** dans `VENTE_CPL`. Dans ce cas, `getById` renvoie `null`, et ma méthode lance l'exception « La vente ... n'existe pas ».

### Morceau 2 : `MV.MONTANT`, ce qui a déjà été payé

Il vient de la vue **`LIAISONPAIEMENTTOTAL`** :

```sql
select id2, sum(nvl(montant,0)) as montant from LIAISONPAIEMENT where etat>=11 group by id2
```

- **`LIAISONPAIEMENT`** : la table des paiements. Chaque ligne dit « la source **`id1`** paie **`montant`** à la facture **`id2`** ». La source peut être :
  - un mouvement de caisse (`MTC...`) : le client a payé en espèces, par chèque, etc. ;
  - un **avoir** (`AVRFC...`) : c'est **exactement** ce que crée `genererPaiementFactureParAvoirAutom` à la validation.
- **`where etat>=11`** : seuls les paiements **visés** comptent. Un paiement juste créé (`etat = 1`) ne diminue pas encore le reste.
- **`sum(...) group by id2`** : tous les paiements d'une même vente sont additionnés.
- **`NVL(MV.MONTANT, 0)`** : une vente sans aucun paiement n'a pas de ligne dans cette vue. Le `LEFT JOIN` donne alors `NULL`, et `NVL` le remplace par `0`.

### Morceau 3 : `ACG.MONTANTTTCAR - ACG.MONTANTPAYEAR`, les avoirs de cette vente

Il vient de la vue **`AVOIRFCMONTANT_GBVENTE`**, qui additionne, **vente par vente**, les avoirs créés **sur** cette vente (`IDVENTE`) :
- **`MONTANTTTCAR`** : le montant TTC (en ariary) des avoirs faits sur cette vente ;
- **`MONTANTPAYEAR`** : la partie de ces avoirs **déjà utilisée** comme paiement ailleurs.

Pourquoi on les retire du reste : un avoir sur une vente, c'est le magasin qui dit « je te dois ce montant sur cette vente » (marchandise à problème, ristourne…). Il **annule** une partie de la dette. Mais si cet avoir a **déjà servi** à payer une autre vente, il ne peut plus annuler celle-ci : on retire donc seulement **la partie pas encore utilisée**.

- Seuls les avoirs **visés** comptent : la vue `AVOIRFCMONTANT` filtre `where a.ETAT>=11`.
- **`NVL(..., 0)`** : pas d'avoir sur cette vente, on retire `0`.

---

## 3. Exemples réels (lus en base)

| vente | TTC | déjà payé | avoirs sur la vente | avoirs déjà utilisés | **MONTANTRESTE** | calcul |
|---|---|---|---|---|---|---|
| `VNT001699001012` | 25 800 | 0 | — | — | **25 800** | 25 800 − 0 − 0 |
| `VNT001539150209` | 49 200 | 15 000 | — | — | **34 200** | 49 200 − 15 000 − 0 |
| `VNT001601153701` | 68 700 | 420 | 420 | 420 | **68 280** | 68 700 − 420 − (420 − 420) |
| `VNT001660162811` | 22 140 | 22 140 | 2 460 | 0 | **−2 460** | 22 140 − 22 140 − (2 460 − 0) |

Les paiements derrière ces chiffres :

```
LP000225 : MTC003123150124 -> VNT001539150209 : 15 000   (paiement en caisse)
LP000303 : AVRFC000274     -> VNT001601153701 :    420   (paiement par un avoir)
```

La 3ᵉ vente montre le chemin complet de l'étape 2 : un avoir (`AVRFC000274`) a payé 420 sur cette vente, grâce à un `LiaisonPaiement`. Ces 420 apparaissent dans « déjà payé », et le reste a baissé d'autant.

---

## 4. Attention : le reste peut être **négatif**

Sur les 300 ventes de la base, **6** ont un `MONTANTRESTE` négatif. Exemple : `VNT001660162811`, entièrement payée (22 140), puis un avoir de 2 460 a été fait dessus. Le reste vaut **−2 460**.

Ça veut dire : **le client ne doit plus rien, c'est le magasin qui lui doit 2 460.** Ces 2 460, c'est justement le crédit qu'on retrouve dans `AVOIRFCLIB_CPL.resteapayerar` et que ma première méthode, `getMontantAvoirDisponible`, additionne. Je l'ai vérifié en base :

```
AVRFC000325 | vente VNT001660162811 | client CLIA0885 | montantttcar 2460 | resteapayerar 2460
```

Les deux vues racontent donc la même chose, vue de deux côtés : la vente a un reste de **−2 460**, et l'avoir du client a **2 460** de crédit disponible.

Dans ma méthode, ce cas est déjà couvert par `Math.max` :

```java
Math.max(0, -2460 - avoir)   // toujours 0 : le client n'a rien à payer
```

Sans le `Math.max`, la méthode aurait renvoyé un montant à payer négatif. C'est une **deuxième raison** de l'avoir mis, en plus de celle de la [partie 1](01_cast_heritage_math_max.md) (avoir plus grand que le reste).

---

## 5. Points de vigilance

| point | conséquence |
|---|---|
| La valeur est une **photo** prise au moment de `getById` | Si un paiement est fait juste après, l'objet `vente` ne le voit pas. Il faut relire la vente. C'est pour ça que ma méthode relit la vente **à chaque appel**. |
| Seuls les paiements et avoirs **visés** (`etat >= 11`) comptent | Un paiement juste créé, pas encore visé, ne diminue pas le reste. |
| La formule mélange les devises | `MONTANTTTC` est dans la **devise de la vente**, alors que le paiement et l'avoir sont en **ariary**. Pour une vente en ariary, aucun problème. En base, **1 seule vente sur 300** n'est pas en ariary. C'est un défaut du code existant, pas de ma méthode : je le note sans le corriger. |

---

## La nouvelle règle d'or

### Règle d'or 10 — Le getter d'une *Lib* ne calcule rien : le calcul est dans la vue

`getMontantreste()`, `getMontantpaye()`, `getResteapayerar()`… ne font que **renvoyer** une valeur recopiée depuis une colonne de vue. Pour comprendre **comment** elle est calculée, il ne faut pas lire le Java : il faut lire la **vue** en base (`select text from user_views where view_name = '...'`). Et pour que la valeur soit remplie, il faut avoir **lu** l'objet avec `getById` ou `rechercher`.

---

## Résumé en une image

```
VENTE_DETAILS ──► VENTEMONTANTLEGER ──► MONTANTTTC ───────────┐
LIAISONPAIEMENT (etat>=11) ──► LIAISONPAIEMENTTOTAL ──► payé ──┤  VENTE_CPL
AVOIRFC (etat>=11) ──► AVOIRFCMONTANT ──► ..._GBVENTE ──► avoir┘  MONTANTRESTE = TTC - payé - (avoir - avoir utilisé)
                                                                        │
                                       getById ──► CGenUtil ──► setMontantreste(...)
                                                                        │
                                                    vente.getMontantreste()  ──► simple return
```
