# Gestion d'avoir — Étape 2 : utiliser l'avoir lors d'un nouvel achat

## Objectif de l'étape

Quand un client a un avoir, je veux qu'il puisse s'en servir pour payer un nouvel achat.

Exemple : le client a **21 500** d'avoir disponible et achète pour **50 000**. Il ne doit plus payer que **28 500**.

Deux routes :
- **le client n'a pas d'avoir disponible** : l'achat se fait normalement, comme aujourd'hui ;
- **le client a un avoir disponible** : le reste à payer est diminué du montant de l'avoir.

## Ce que j'ai analysé avant d'écrire le code (et pourquoi)

### 1. Le projet consomme déjà les avoirs, à la validation

`VenteArbiochem.validerObject(...)` ([VenteArbiochem.java:247](../../arbiochem-ejb/src/java/vente/VenteArbiochem.java#L247)) est appelé quand on clique sur **Valider** dans `vente-arbiochem-fiche.jsp`. Il appelle `genererPaiementFactureParAvoirAutom(...)` (ligne 60), qui :

1. cherche les avoirs du client qui ont encore un reste (`AVOIRFCLIB_CPL`, `resteapayerar > 0`) ;
2. calcule `min(total des avoirs, reste de la facture)` ;
3. crée un **paiement** (`LiaisonPaiement`) entre l'avoir et la facture.

**Je ne refais donc pas la consommation de l'avoir.** Il me manque seulement une façon de **savoir à l'avance** combien le client a d'avoir disponible, et combien il lui restera à payer.

### 2. L'avoir est un moyen de paiement, pas une remise

J'ai choisi de **ne pas baisser le prix** de la nouvelle vente (50 000 → 28 500) :

| si je baissais le prix | avec l'avoir comme paiement |
|---|---|
| chiffre d'affaires et TVA de la vente **faux** | la vente reste à 50 000, c'est ce que le client a acheté |
| rien ne note que l'avoir a servi : il peut être **réutilisé à l'infini** | le paiement `LiaisonPaiement` diminue le reste de l'avoir |
| un avoir plus grand que l'achat est **perdu** | ce qui n'est pas utilisé reste disponible pour la prochaine fois |

### 3. « Avoir disponible » ne veut pas dire « avoir créé »

La vue `AVOIRFCLIB_CPL` calcule `RESTEAPAYERAR`, ce qui reste **vraiment** utilisable dans un avoir. L'avoir sert d'abord à annuler ce que le client doit encore sur la vente d'origine. Seul ce qui dépasse devient un crédit, auquel on retire ce qui a déjà été utilisé.

Exemple réel, vérifié en base :

| | valeur |
|---|---|
| avoir `AVRFC000335` (vente `VNT001700090211`, client `CLIA2625`), montant TTC | 25 800 |
| ce que le client a déjà payé sur cette vente | 0 |
| **`RESTEAPAYERAR`** | **0** |

Le client n'a jamais payé cette vente : l'avoir annule simplement sa dette. Il ne lui reste **aucun** crédit à dépenser.

Je raisonne aussi en **TTC** (`...AR` = TTC en ariary) : 25 800, et pas les 21 500 HT.

## Fichiers touchés dans cette étape

| Fichier | Ce que j'ai fait | Documentation détaillée |
|---|---|---|
| `arbiochem-ejb/src/java/vente/Vente.java` | J'ai **ajouté** la méthode `getMontantAvoirDisponible(Connection c)`, lignes 1543 à 1564. | [Vente.java.md](Vente.java.md) → Modification 1 |
| `arbiochem-ejb/src/java/vente/Vente.java` | J'ai **ajouté** la méthode `getMontantAPayerApresAvoir(Connection c)`, lignes 1565 à 1585. | [Vente.java.md](Vente.java.md) → Modification 2 |

Aucun écran (JSP), aucune table et aucune vue n'ont été modifiés.

> 📚 Pour comprendre `AvoirFC` / `AvoirFCLib`, `setNomTable`, `CGenUtil` et `AdminGen` utilisés dans ces méthodes : [apprentissageAPJ/lecon2/01_lire_en_base.md](../../apprentissageAPJ/lecon2/01_lire_en_base.md).
>
> 📚 Pour comprendre le cast `(VenteLib)`, l'héritage `VenteLib extends Vente` et `Math.max` utilisés dans `getMontantAPayerApresAvoir` : [apprentissageAPJ/lecon3/01_cast_heritage_math_max.md](../../apprentissageAPJ/lecon3/01_cast_heritage_math_max.md).
>
> 📚 Pour comprendre `getMontantreste()` (la formule de la vue `VENTE_CPL`) : [apprentissageAPJ/lecon3/02_getMontantreste.md](../../apprentissageAPJ/lecon3/02_getMontantreste.md).

## Les décisions que j'ai prises (et pourquoi)

| Décision | Pourquoi |
|---|---|
| La méthode **lit seulement**, elle ne crée et ne modifie rien | Elle sert à vérifier et à afficher. La consommation de l'avoir existe déjà dans `validerObject`. |
| Je réutilise la vue `AVOIRFCLIB_CPL` et la colonne `resteapayerar` | C'est ce que le code existant utilise déjà (`genererPaiementFactureParAvoirAutom`). Si je calculais autrement, l'affichage et la consommation réelle pourraient ne pas être d'accord. |
| Méthode **d'instance** (pas `static`) | Elle répond à une question sur **cette** vente : « combien d'avoir a son client ? ». Elle utilise `this.getIdClient()`. |
| Elle renvoie `0` s'il n'y a pas d'avoir | La route « pas d'avoir » est donc simplement `if (montant == 0)`. Pas de `null`, pas d'exception. |
| `getMontantAPayerApresAvoir` part du **reste à payer** (`VENTE_CPL.montantreste`), pas du montant TTC | Si le client a déjà payé une partie, je ne lui redemande que ce qu'il doit encore. C'est aussi le montant que `genererPaiementFactureParAvoirAutom` utilise à la validation. |
| `getMontantAPayerApresAvoir` **réutilise** `getMontantAvoirDisponible` | Le calcul de l'avoir n'existe qu'à un seul endroit. |
| Résultat avec `Math.max(0, ...)` | Un avoir plus grand que l'achat donne `0` à payer, jamais un montant négatif. Le surplus reste dans l'avoir. |
| Vente introuvable : **exception**, pas `0` | Renvoyer `0` voudrait dire « rien à payer », ce qui serait faux. |

## Comment je l'ai testé

1. **Compilation** de `Vente.java` contre les bibliothèques du projet : aucune erreur.
2. **Test réel sur la base**, en **lecture seule**, avec un programme jetable (hors projet) qui crée une `Vente` en mémoire, lui donne un client et appelle la méthode :

```
Client 'CLIA2625' -> avoir disponible : 0.0        <- avoir créé, mais vente d'origine jamais payée
Client 'CLIA0220' -> avoir disponible : 393600.0   <- 1 avoir disponible
Client 'CLIA0935' -> avoir disponible : 25440.0    <- 3 avoirs disponibles, additionnés
Sans connexion (null) CLIA0935 -> 25440.0          <- la méthode ouvre et ferme sa propre connexion
```

J'ai comparé ces valeurs avec la requête SQL `select idclient, sum(resteapayerar) from AVOIRFCLIB_CPL where resteapayerar > 0 group by idclient` : elles sont identiques.

### Test de `getMontantAPayerApresAvoir`

Compilation : aucune erreur. Puis deux programmes jetables (hors projet, dans mon dossier temporaire), qui se terminent tous les deux par un **ROLLBACK**.

**a) Données réelles, en lecture seule :**

```
CLIA0220 | vente VNT001579135221 | reste 0.0     | avoir 393600.0 | apres avoir 0.0
CLIA0935 | vente VNT001439094718 | reste 0.0     | avoir 25440.0  | apres avoir 0.0
CLIA2625 | vente VNT001699001012 | reste 25800.0 | avoir 0.0      | apres avoir 25800.0   <- route « pas d'avoir »
Inexistante -> La vente VNT_INEXISTANTE n'existe pas
```

En base, les clients qui ont un avoir n'ont **aucune** vente non payée. Je ne pouvais donc pas tester la soustraction avec les données telles quelles.

**b) Simulation de la route « avec avoir » :** dans une transaction, j'ai rattaché temporairement deux ventes non payées au client `CLIA0935` (25 440 d'avoir), j'ai appelé la méthode, puis j'ai fait un **ROLLBACK** :

```
vente VNT001699001012 | reste 25800.0 | avoir 25440 | apres avoir 360.0   <- 25 800 - 25 440
vente VNT001504105224 | reste 3420.0  | avoir 25440 | apres avoir 0.0     <- avoir plus grand que la vente
ROLLBACK effectue
```

J'ai ensuite relu la base : les deux ventes ont bien retrouvé leur client d'origine (`CLIA2625` et `CLIA0129`). Rien n'a été modifié.

> Je n'ai **pas** relancé `ant` : aucun écran n'utilise encore ces méthodes. Il faudra le faire quand on les affichera.

## Ce qui n'est pas encore fait (prochaines étapes)

- Afficher ces deux montants sur la fiche de la vente.
- La vue ne regarde pas l'état de l'avoir : un avoir **annulé** (`etat = 0`) pourrait encore être compté. Le code existant (`genererPaiementFactureParAvoirAutom`) fait pareil. Je garde le même comportement pour rester cohérent, mais c'est à vérifier.
