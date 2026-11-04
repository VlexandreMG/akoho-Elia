# Leçon 4 : à quoi sert `apresMultiple.jsp`

> **Ce que fait le fichier :** `apresMultiple.jsp` reçoit un formulaire, fabrique les objets Java demandés, exécute l'action choisie par le champ `acte`, puis redirige vers l'écran suivant.

Fichier : [apresMultiple.jsp](../../arbiochem-war/web/pages/apresMultiple.jsp)

## Sa place dans APJ

C'est une page **sans écran** : elle traite la demande puis renvoie aussitôt vers une autre page. Grâce à elle, chaque écran de saisie n'a pas besoin de réécrire sa propre logique d'enregistrement. Environ 150 JSP du projet la mentionnent.

```
écran de saisie                        apresMultiple.jsp                       fiche
(formulaire + champs cachés) ──POST──▶ lit, construit, exécute ──redirection──▶ (bute)
```

Elle fait le lien entre l'écran et la couche métier. Elle ne contient pas les règles de gestion : elles restent dans les classes Java, comme `Vente`.

## Les champs envoyés par le formulaire

| Champ caché | Exemple pour une vente | Rôle |
|---|---|---|
| `acte` | `insert` | l'action à exécuter |
| `classe` | `vente.Vente` | la classe de la mère |
| `classefille` | `vente.VenteDetailsArbiochem` | la classe des lignes |
| `colonneMere` | `idVente` | la colonne qui relie une ligne à sa mère |
| `nomtable` | table ou vue choisie par l'écran | la table imposée aux lignes |
| `nombreLigne` | `10` | le nombre de lignes à lire |
| `bute` | `vente/vente-arbiochem-fiche.jsp` | la page à ouvrir après le succès |

## Ce qu'elle fait, étape par étape

1. **Elle lit les paramètres** : `acte`, `classe`, `bute`, `id`… Elle récupère aussi l'utilisateur connecté dans la session.
2. **Elle crée l'objet par réflexion** : `Class.forName(classe).newInstance()` crée un objet à partir du nom de sa classe, reçu sous forme de texte. C'est pour ça qu'une seule page peut servir à tous les modules.
3. **Elle applique la règle `insert` → `updateInsert`** : si `acte` vaut `insert` mais que l'id est déjà rempli, l'action devient `updateInsert`.
4. **Elle remplit les objets** : `PageInsertMultiple` ou `PageUpdateMultiple` recopient les valeurs du formulaire dans la mère et dans ses filles.
5. **Elle appelle le métier** : par exemple `u.createObjectMultiple(...)` ou `u.updateObjectMultiple(...)`.
6. **Elle redirige** vers `bute`, souvent avec l'id de l'objet.
7. **En cas d'erreur**, elle affiche le message de l'exception dans une alerte, puis revient à la page précédente.

## Les principales actions

| `acte` | Ce qu'il fait | Appel principal |
|---|---|---|
| `insert` | crée une mère et ses filles avec les contrôles | `u.createObjectMultiple(...)` |
| `insertSansControle` | crée une mère et ses filles, sans les contrôles des filles | `u.createObjectMultiple(...)` |
| `updateInsert` | modifie une mère et ses filles | `u.updateObjectMultiple(...)` |
| `update` | modifie un objet simple, sans filles | `u.updateObject(...)` |
| `valider` | valide un objet | `u.validerObject(...)` |

Le fichier gère aussi d'autres actions : `delete`, `annuler`, `annulerVisa`, `dupliquer`, `cloturer`, etc.

## Le chemin de notre modification de vente

Pourquoi le log affiche-t-il `ACTEinsert` alors qu'on modifie une vente ?

1. Le formulaire de `vente-arbiochem-saisie.jsp` envoie toujours `acte=insert`.
2. La ligne `System.out.println("ACTE" + acte)` affiche donc `ACTEinsert`.
3. L'id de la vente est rempli, donc `acte` devient `updateInsert` **après** cet affichage.
4. La page appelle `u.updateObjectMultiple(...)`.
5. Le chemin continue comme dans la [leçon 1](../lecon1/01_chemin_modification.md) jusqu'à `Vente.updateToTableWithHisto(u, c)`, où se trouve notre trigger métier.

## Les règles d'or

### Règle d'or 7 — Le même écran peut créer et modifier

> **Avec `acte=insert`, c'est la présence de l'id qui décide : pas d'id, création ; id rempli, modification.**

### Règle d'or 8 — Le log `ACTE...` montre la valeur reçue

> **`ACTEinsert` dans le log ne prouve pas qu'un `INSERT` a eu lieu.**

Pour savoir ce qui s'est vraiment passé, je regarde la requête `INSERT` ou `UPDATE` affichée ensuite.

### Règle d'or 9 — Le message d'erreur vient du métier

> **Dans le métier, un simple `throw new Exception("message")` suffit : `apresMultiple.jsp` l'affiche à l'utilisateur.**

### Règle d'or 10 — Tous les écrans ne passent pas par cette page

> **Il faut toujours regarder l'adresse du bouton ou du formulaire.**

Par exemple, le bouton **Viser** de la fiche passe par `apresTarif.jsp`, et le bouton rouge **Annuler** d'une vente visée passe par `vente/apres-annuler.jsp`.

## Un point de vigilance

Les variables du bloc `<%! ... %>` (`u`, `acte`, `bute`…) appartiennent à la page, et non à une requête. Deux utilisateurs qui enregistrent exactement au même moment pourraient donc se mélanger leurs valeurs. C'est un risque hérité du code d'origine.

## En une phrase

> `apresMultiple.jsp` est le **point d'arrivée commun des formulaires** : l'écran dit quoi faire, la page construit les objets, le métier applique les règles.
