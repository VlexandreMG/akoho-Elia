# Gestion d'avoir — Étape 1 : correction du `StackOverflowError`

## Le symptôme

Sur `vente-arbiochem-fiche.jsp`, je clique sur **Modifier**. J'arrive sur `vente-arbiochem-saisie.jsp&acte=update`, je mets **Problème = Oui** et je clique sur **Enregistrer**. La page plante avec un `java.lang.StackOverflowError`.

## Ce que j'ai cherché, dans l'ordre

### 1. Est-ce que l'écran appelle bien mon trigger ?

Dans `vente-arbiochem-saisie.jsp` (lignes 320-321), quand `acte` est présent, la classe postée est `vente.Vente`. Le formulaire part vers `apresMultiple.jsp`, qui suit le chemin décrit dans la leçon 1 jusqu'à `Vente.updateToTableWithHisto(u, c)`. **Mon trigger est donc bien appelé.**

### 2. Que dit le log de WildFly ?

Fichier : `wildfly-10.1.0.Final/standalone/log/server.log`

```
09:03:11,677 INFO  [stdout] (default task-214) ACTEinsert
09:03:11,727 INFO  [stdout] (default task-214) Requete select rechercher : select * from VENTE where 1<2 and id like 'VNT001700090211'
09:03:11,731 INFO  [stdout] (default task-214) Requete select rechercher : select * from VENTE where 1<2 and id like 'VNT001700090211'
09:03:11,733 INFO  [stdout] (default task-214) Requete select rechercher : select * from VENTE where 1<2 and id like 'VNT001700090211'
... (28 744 fois la même ligne)
```

- `select * from VENTE ... id like '...'` est **exactement** la requête de `Vente.getById(c, id)`, donc mon **exercice 1** (`Vente ancienne = Vente.getById(c, this.getId());`).
- Elle se répète **à l'infini**, sans **aucun** `UPDATE` entre deux lectures.

Conclusion : la méthode lit `ancienne`, puis, au lieu de faire l'`UPDATE`, **se rappelle elle-même**, qui relit `ancienne`, qui se rappelle… jusqu'à ce que la pile d'appels de Java soit pleine (`StackOverflowError`). C'est exactement le scénario « `this.` au lieu de `super.` » de l'exercice 2.

### 3. Pourtant, mon code source est juste

Dans `arbiochem-ejb/src/java/vente/Vente.java`, ligne 632 :

```java
int retour = super.updateToTableWithHisto(u,c);
```

C'est bien `super`. Le problème ne vient donc pas du **code source**, mais de **ce qui tourne réellement sur le serveur**.

### 4. Je regarde le `.class` déployé sur WildFly

Le serveur n'exécute pas mon `.java`, il exécute le `.class` compilé qui se trouve dans :

```
wildfly-10.1.0.Final/standalone/deployments/prog-elia.war/WEB-INF/lib/arbiochem-ejb.jar
```

Je l'ai désassemblé avec `javap -c` :

```
 5: invokestatic  getById(Connection, String)          <- exercice 1
12: invokevirtual updateToTableWithHisto(String, Connection)   <- !!!
```

- **`invokevirtual`**, c'est l'instruction d'un appel **normal** : `this.updateToTableWithHisto(...)`, ou simplement `updateToTableWithHisto(...)`. Java appelle alors **la version de `Vente`**, c'est-à-dire elle-même → boucle infinie.
- Un appel **`super.`** donne une autre instruction, **`invokespecial`**, qui vise directement la classe parente.
- Il n'y a **pas** de `getProbleme()` ni de `genererAvoir2` : ce `.class` ne contient même pas les exercices 3 et 4.

### 5. D'où vient ce vieux `.class` ?

| moment | événement |
|---|---|
| 01:42 | commit « Exo 1 done » |
| **01:50** | **dernier déploiement** sur WildFly (`arbiochem-ejb.jar` daté de 01:50) |
| 01:59 | commit « Exo 2 done » (avec `super`) |
| 07:40 → 08:54 | commits des exercices 3, 4 et 5 |

Le serveur faisait tourner une version **intermédiaire** de l'exercice 2, compilée pendant que j'écrivais encore la ligne (sans `super`). Depuis, j'ai corrigé et fini les exercices 3 à 5 dans le code source, mais **je n'ai jamais relancé `ant`** : WildFly n'a jamais reçu la bonne version.

## La solution

**Aucune ligne de code à changer.** J'ai simplement recompilé et redéployé, depuis la racine du projet :

```bash
ant
```

- `ant` lit `build.xml` (cible par défaut : `deploy`). Il recompile `arbiochem-ejb`, refabrique `arbiochem-ejb.jar`, le copie dans `deployments/prog-elia.war`, puis crée le fichier `prog-elia.war.dodeploy`.
- Ce fichier `.dodeploy` est le signal pour WildFly : « recharge cette application ».

Résultat :

```
BUILD SUCCESSFUL
09:09:02 WFLYUT0021: Registered web context: /prog-elia
09:09:02 WFLYSRV0016: Replaced deployment "prog-elia.war" with deployment "prog-elia.war"
```

## Vérification

J'ai re-désassemblé le `.class` **déployé** :

```
 5: invokestatic  getById(Connection, String)                          <- exercice 1
12: invokespecial vente/FactureCF.updateToTableWithHisto(String, Connection)   <- exercice 2 : super
18: invokevirtual getProbleme()                                        <- exercice 3 (this)
30: invokevirtual getProbleme()                                        <- exercice 3 (ancienne)
43: invokestatic  genererAvoir2(String, Connection, String)             <- exercice 4
```

- **`invokespecial vente/FactureCF...`** : c'est bien `super`. Java le note « `FactureCF` » parce que c'est le **parent direct** de `Vente`. À l'exécution, il remonte jusqu'à `ClassMAPTable`, la première classe qui définit vraiment la méthode.
- Les exercices 3 et 4 sont maintenant présents sur le serveur.

## Ce que je retiens

1. **Le serveur n'exécute pas mon `.java`, il exécute le dernier `.class` déployé.** Après chaque modification d'une classe Java, je dois relancer `ant`.
2. **Un `StackOverflowError` avec la même requête répétée** signifie qu'une méthode se rappelle elle-même. Dans une méthode `@Override`, je vérifie en premier qu'elle appelle bien `super.` et pas `this.`.
3. **`javap -c`** permet de voir ce qui est **vraiment** compilé :
   - `invokevirtual` = appel normal (`this.`) ;
   - `invokespecial` = appel au parent (`super.`) ;
   - `invokestatic` = méthode `static` (`Vente.getById`).

## Rappel de la limite connue

L'avoir ne sera créé depuis cet écran que si la vente n'est **pas encore validée** (`etat < 11`). Pour une vente validée, `ClassEtat.updateObject` refuse la modification **avant** d'arriver à mon trigger (voir [apprentissageAPJ/lecon1/01_chemin_modification.md](../../apprentissageAPJ/lecon1/01_chemin_modification.md), étage 4).
