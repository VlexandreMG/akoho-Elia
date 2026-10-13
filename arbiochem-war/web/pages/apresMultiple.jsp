<%--
    Document   : apresMultiple
    Created on : Oct 19, 2018
    Author     : Jerry

    RÔLE DE CE FICHIER :
    C'est LE moteur central d'APJ. TOUS les écrans de saisie/modification
    postent vers ce fichier. Il lit le paramètre "acte" et exécute
    l'action correspondante (insert, update, valider, delete…) sur
    l'objet Java dont le nom est passé dans "classe".

    En résumé : c'est un GROS SWITCH basé sur des if (acte.equals(...)).
--%>

<%-- ═══════════════════════════════════════════════════════════════
     BLOC 0 — IMPORTS
     Comme en Java. Sans ces imports, les classes ne sont pas reconnues.
     ═══════════════════════════════════════════════════════════════ --%>
<%@page import="constante.ConstanteEtat"%>       <%-- Les états (0, 1, 11, 20...) --%>
<%@ page import="user.*" %>                        <%-- UserEJB : l'utilisateur connecté --%>
<%@ page import="utilitaire.*" %>                  <%-- Utilitaire, UtilDB... --%>
<%@ page import="bean.*" %>                        <%-- ClassMAPTable, ClassMere, ClassFille, ClassEtat --%>
<%@ page import="java.sql.SQLException" %>         <%-- Pour les exceptions SQL --%>
<%@ page import="java.sql.Date" %>                 <%-- Pour les dates SQL --%>
<%@ page import="affichage.*" %>                   <%-- PageInsertMultiple, PageUpdateMultiple, Page... --%>
<%@ page import="facture.tr.Traite" %>             <%-- Cas très spécifique au module Traite --%>

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>

    <%-- ═══════════════════════════════════════════════════════════════
         BLOC 1 — DÉCLARATION DES VARIABLES DE CLASSE
         
         ⚠ ATTENTION : <%! ... %> (avec un point d'exclamation) déclare
         des variables au niveau INSTANCE de la Servlet JSP.
         Elles sont partagées entre TOUTES les requêtes → dangereux en
         production (thread safety), mais c'est l'héritage historique d'APJ.
         ═══════════════════════════════════════════════════════════════ --%>
    <%!
        UserEJB u = null;         // L'utilisateur connecté (récupéré de la session)
        String acte = null;       // L'action à faire : "insert", "update", "valider"…
        String lien = null;       // Le module.jsp de base (pour la redirection)
        String bute;              // Où rediriger après succès (la fiche, la liste…)
        String nomtable = null;   // Nom de la table cible de la fille
        String typeBoutton;       // 3 = modification par défaut (historique)
        String ben;               // Doublon de nomtable (pas utilisé, vestige)
        String[] tId;             // Tableau d'IDs (pour validerMultiple, deleteMultiple…)
    %>

    <%
        try {
            // ═══════════════════════════════════════════════════════════════
            // BLOC 2 — LECTURE DE TOUS LES PARAMÈTRES DU POST
            //
            // Le JSP précédent (bondecommande-arbiochem-saisie.jsp) a envoyé
            // un <form> avec plein de <input type="hidden">. On les lit ici.
            // ═══════════════════════════════════════════════════════════════

            ben        = request.getParameter("nomtable");     // (doublon, vestige)
            nomtable   = request.getParameter("nomtable");     // ex. "AS_BONDECOMMANDE_FILLE"
            typeBoutton = request.getParameter("type");        // 3 par défaut
            lien       = (String) session.getValue("lien");    // le module.jsp de base
            u          = (UserEJB) session.getAttribute("u");  // l'utilisateur connecté
            acte       = request.getParameter("acte");         // ⭐ "insert", "update"…
            System.out.println("ACTE" + acte);                 // debug console

            bute       = request.getParameter("bute");         // où rediriger après succès

            Object temp = null;                                // objet temporaire (retour)
            String[] rajoutLien = null;                        // paramètres additionnels URL
            String classe = request.getParameter("classe");    // ⭐ FQN de la classe mère
            ClassMAPTable t = null;                            // objet de travail
            String tempRajout = request.getParameter("rajoutLien");  // ex. "idlot-iddmdachat"
            String val = "";                                   // valeur de retour
            String id = request.getParameter("id");            // id simple (1 objet)
            tId = request.getParameterValues("ids");           // ⭐ ids MULTIPLES (checkbox)

            String nombreLigneS = request.getParameter("nombreLigne");
            int nombreLigne = Utilitaire.stringToInt(nombreLigneS);  // "10" → 10

            // ═══════════════════════════════════════════════════════════════
            // BLOC 3 — INSTANCIATION PAR RÉFLEXION
            //
            // ⭐ C'EST LE CŒUR D'APJ :
            // Class.forName("faturefournisseur.As_BonDeCommande")
            //   → crée une instance de cette classe SANS la connaître à la
            //     compilation. C'est ce qui permet au MÊME apresMultiple.jsp
            //     de servir TOUS les modules du projet.
            // ═══════════════════════════════════════════════════════════════
            ClassMAPTable classTemp = (ClassMAPTable) (Class.forName(classe).newInstance());

            // ⭐ RÈGLE MAGIQUE :
            // Si on demande "insert" MAIS qu'un id est déjà présent dans le POST,
            // c'est en fait un UPDATE. On bascule automatiquement.
            // → C'est pour ça que le même écran -saisie.jsp sert à créer ET modifier.
            if (acte.equalsIgnoreCase("insert")
                && request.getParameter(classTemp.getAttributIDName()) != null
                && !request.getParameter(classTemp.getAttributIDName()).isEmpty()) {
                acte = "updateInsert";
            }

            // Lecture des variables de navigation mère/fille
            String idmere        = request.getParameter("idmere");        // id de la mère
            String classefille   = request.getParameter("classefille");   // FQN de la fille
            ClassMAPTable mere   = null;                                  // objet mère (à créer)
            ClassMAPTable fille  = null;                                  // objet fille (à créer)
            String colonneMere   = request.getParameter("colonneMere");   // ex. "idbc"
            String nombreDeLigne = request.getParameter("nombreLigne");   // relecture (doublon)
            int nbLine           = Utilitaire.stringToInt(nombreDeLigne);

            // Gestion des paramètres additionnels (ex. "idlot-iddmdachat")
            // Format : "param1-param2-param3" dans le champ "rajoutLien"
            String rajoutLie = "";
            if (tempRajout != null && tempRajout.compareToIgnoreCase("") != 0) {
                rajoutLien = utilitaire.Utilitaire.split(tempRajout, "-");
            }

            // Valeurs par défaut si non fournies
            if (bute == null || bute.compareToIgnoreCase("") == 0) {
                bute = "pub/Pub.jsp";        // page par défaut (générique)
            }
            if (classe == null || classe.compareToIgnoreCase("") == 0) {
                classe = "pub.Montant";      // classe par défaut (dummy)
            }
            if (typeBoutton == null || typeBoutton.compareToIgnoreCase("") == 0) {
                typeBoutton = "3";           // 3 = modification (historique)
            }
            int type = Utilitaire.stringToInt(typeBoutton);

            // ═══════════════════════════════════════════════════════════════
            // BLOC 4 — LES ACTIONS, UNE PAR UNE
            //
            // À partir d'ici, c'est une succession de if (acte.equals(...)).
            // Chaque bloc gère UNE action.
            // ═══════════════════════════════════════════════════════════════

            // ───────────────────────────────────────────────────────────────
            // ACTION : insertSansControle
            // Créer mère + filles SANS déclencher les contrôles métier.
            // ───────────────────────────────────────────────────────────────
            if (acte != null && acte.compareToIgnoreCase("insertSansControle") == 0) {
                // 1) Instancie la mère et la fille par réflexion
                mere  = (ClassMAPTable) (Class.forName(classe).newInstance());
                fille = (ClassMAPTable) (Class.forName(classefille).newInstance());

                // 2) PageInsertMultiple va extraire les valeurs du request
                PageInsertMultiple p = new PageInsertMultiple(mere, fille, request, nbLine, tId);

                // 3) Remplit la mère avec les champs du POST
                ClassMAPTable cmere = p.getObjectAvecValeur();

                // 4) ⭐ Remplit les filles SANS appeler createObject()
                ClassMAPTable[] cfille = p.getObjectFilleAvecValeurSansControle();

                // 5) Force la table cible de chaque ligne
                for (int i = 0; i < cfille.length; i++) {
                    cfille[i].setNomTable(nomtable);
                }

                // 6) INSERT en base : mère + filles
                ClassMAPTable o = (ClassMAPTable) u.createObjectMultiple(cmere, colonneMere, cfille);

                temp = (Object) o;
                if (temp != null) {
                    val = temp.toString();
                    idmere = o.getTuppleID();   // récupère l'id généré
                }
%>
                <%-- 7) Redirection vers la fiche de l'objet créé --%>
                <script language="JavaScript">
                    document.location.replace("<%=lien%>?but=<%=bute%>&id=<%=idmere%>");
                </script>
<%          }

            // ───────────────────────────────────────────────────────────────
            // ACTION : interview (spécifique RH/recrutement)
            // ───────────────────────────────────────────────────────────────
            if (acte != null && acte.compareToIgnoreCase("interview") == 0) {
                mere  = (ClassMAPTable) (Class.forName(classe).newInstance());
                fille = (ClassMAPTable) (Class.forName(classefille).newInstance());
                PageUpdateMultiple p = new PageUpdateMultiple(mere, fille, request, nbLine, tId);

                ClassMAPTable cmere = p.getObjectAvecValeur();
                ClassMAPTable[] cfille = p.getObjectFilleAvecValeurSansControle();

                for (int i = 0; i < cfille.length; i++) {
                    cfille[i].setNomTable(nomtable);
                }

                // ⭐ Force l'état à "Interviewe"
                ((ClassEtat) cmere).setEtat(ConstanteEtat.getEtatInterviewe());

                ClassMAPTable o = (ClassMAPTable) u.updateObjectMultiple(cmere, colonneMere, cfille);
                temp = (Object) o;
                if (temp != null) {
                    val = temp.toString();
                    idmere = o.getTuppleID();
                }
%>
                <script language="JavaScript">
                    document.location.replace("<%=lien%>?but=<%=bute%>&id=<%=idmere%>");
                </script>
<%          }

            // ───────────────────────────────────────────────────────────────
            // ACTION : updateSansControle (modifier sans contrôles)
            // ───────────────────────────────────────────────────────────────
            if (acte != null && acte.compareToIgnoreCase("updateSansControle") == 0) {
                mere  = (ClassMAPTable) (Class.forName(classe).newInstance());
                fille = (ClassMAPTable) (Class.forName(classefille).newInstance());
                PageUpdateMultiple p = new PageUpdateMultiple(mere, fille, request, nbLine, tId);

                ClassMAPTable cmere = p.getObjectAvecValeur();
                ClassMAPTable[] cfille = p.getObjectFilleAvecValeurSansControle();

                for (int i = 0; i < cfille.length; i++) {
                    cfille[i].setNomTable(nomtable);
                }
                ClassMAPTable o = (ClassMAPTable) u.updateObjectMultiple(cmere, colonneMere, cfille);
                temp = (Object) o;
                if (temp != null) {
                    val = temp.toString();
                    idmere = o.getTuppleID();
                }
%>
                <script language="JavaScript">
                    document.location.replace("<%=lien%>?but=<%=bute%>&id=<%=idmere%>");
                </script>
<%          }

            // ═══════════════════════════════════════════════════════════════
            // ACTION : insert  ⭐⭐ LA PLUS IMPORTANTE
            //
            // C'est CE bloc qui tourne quand tu cliques "Enregistrer" sur
            // ton bon de commande.
            //
            // DIFFÉRENCE avec insertSansControle :
            //   getObjectFilleAvecValeur()  → AVEC contrôles
            //   getObjectFilleAvecValeurSansControle() → SANS contrôles
            // ═══════════════════════════════════════════════════════════════
            if (acte != null && acte.compareToIgnoreCase("insert") == 0) {
                // 1) Instancie mère + fille
                mere  = (ClassMAPTable) (Class.forName(classe).newInstance());
                fille = (ClassMAPTable) (Class.forName(classefille).newInstance());

                // 2) Moteur d'extraction
                PageInsertMultiple p = new PageInsertMultiple(mere, fille, request, nbLine, tId);

                // 3) Remplit la mère
                ClassMAPTable cmere = p.getObjectAvecValeur();

                // 4) ⭐ Remplit les filles AVEC contrôle (appelle createObject())
                ClassMAPTable[] cfille = p.getObjectFilleAvecValeur();

                // 5) Force la table cible
                for (int i = 0; i < cfille.length; i++) {
                    cfille[i].setNomTable(nomtable);
                }

                // 6) ⭐ INSERT : mère + filles
                //    C'est ICI que mere.createObject() est appelé → tes contrôles métier
                ClassMAPTable o = (ClassMAPTable) u.createObjectMultiple(cmere, colonneMere, cfille);
                temp = (Object) o;
                if (temp != null) {
                    val = temp.toString();
                    idmere = o.getTuppleID();
                }
%>
                <%-- 7) Redirection vers la fiche --%>
                <script language="JavaScript">
                    document.location.replace("<%=lien%>?but=<%=bute%>&id=<%=idmere%>");
                </script>
<%          }

            // ───────────────────────────────────────────────────────────────
            // ACTION : insertFille (ajouter des lignes à une mère EXISTANTE)
            // ───────────────────────────────────────────────────────────────
            if (acte != null && acte.compareToIgnoreCase("insertFille") == 0) {
                mere  = (ClassMAPTable) (Class.forName(classe).newInstance());
                fille = (ClassMAPTable) (Class.forName(classefille).newInstance());
                PageInsertMultiple p = new PageInsertMultiple(mere, fille, request, nbLine, tId);

                ClassMAPTable[] cfille = p.getObjectFilleAvecValeur();
                for (int i = 0; i < cfille.length; i++) {
                    cfille[i].setNomTable(nomtable);
                }

                String idMere = request.getParameter("idMere");
                if (idMere == null || idMere.isEmpty()) {
                    throw new Exception("Id mere not provided");   // ⚠ la mère est OBLIGATOIRE
                }

                // ⭐ Crée seulement les filles, rattachées à une mère existante
                u.createObjectFilleMultiple(idMere, colonneMere, cfille);
%>
                <script language="JavaScript">
                    document.location.replace("<%=lien%>?but=<%=bute%>&id=<%=idMere%>");
                </script>
<%          }

            // ───────────────────────────────────────────────────────────────
            // ACTION : insertFilleSeul (créer des filles SANS mère)
            // ───────────────────────────────────────────────────────────────
            if (acte != null && acte.compareToIgnoreCase("insertFilleSeul") == 0) {
                mere  = (ClassMAPTable) (Class.forName(classe).newInstance());
                fille = (ClassMAPTable) (Class.forName(classefille).newInstance());
                PageInsertMultiple p = new PageInsertMultiple(mere, fille, request, nbLine, tId);

                ClassMAPTable[] cfille = p.getObjectFilleAvecValeur();

                // Chaque fille est créée INDÉPENDAMMENT (pas de mère)
                for (int i = 0; i < cfille.length; i++) {
                    ClassMAPTable tmp = cfille[i];
                    u.createObject(tmp);   // ⭐ INSERT individuel
                }
%>
                <script language="JavaScript">
                    document.location.replace("<%=lien%>?but=<%=bute%>");
                </script>
<%          }

            // ═══════════════════════════════════════════════════════════════
            // ACTION : updateInsert  ⭐⭐
            //
            // ⚠ C'est ICI qu'on arrive quand l'id est déjà rempli (règle du bloc 3).
            // Donc : le même écran -saisie.jsp sert à CRÉER et à MODIFIER.
            // ═══════════════════════════════════════════════════════════════
            if (acte != null && acte.compareToIgnoreCase("updateInsert") == 0) {
                mere  = (ClassMAPTable) (Class.forName(classe).newInstance());
                fille = (ClassMAPTable) (Class.forName(classefille).newInstance());

                // ⚠ PageUpdateMultiple au lieu de PageInsertMultiple
                PageUpdateMultiple p = new PageUpdateMultiple(mere, fille, request, nbLine, tId);

                ClassMAPTable cmere = p.getObjectAvecValeur();
                ClassMAPTable[] cfille = p.getObjectFilleAvecValeur();

                for (int i = 0; i < cfille.length; i++) {
                    cfille[i].setNomTable(nomtable);
                }

                // ⭐ UPDATE (pas INSERT)
                ClassMAPTable o = (ClassMAPTable) u.updateObjectMultiple(cmere, colonneMere, cfille);
                temp = (Object) o;
                if (temp != null) {
                    val = temp.toString();
                    idmere = o.getTuppleID();
                }
%>
                <script language="JavaScript">
                    document.location.replace("<%=lien%>?but=<%=bute%>&id=<%=idmere%>");
                </script>
<%          }

            // ───────────────────────────────────────────────────────────────
            // ACTION : viserTraite (module financier — effets bancaires)
            // ───────────────────────────────────────────────────────────────
            if (acte.equals("viserTraite")) {
                Traite traite = new Traite();
                traite.avantVerser(tId, u.getUser().getTuppleID(),
                                   request.getParameter("idcaisse"),
                                   request.getParameter("date"), null);
            }
            if (acte.equals("viserTraiteSimple")) {
                Traite traite = new Traite();
                Date daty = Utilitaire.stringDate(request.getParameter("daty"));
                traite.setDaty(daty);
                traite.setId(id);
                String[] value = {request.getParameter("idTraite")};
                traite.avantVerser(value, u.getUser().getTuppleID(),
                                   request.getParameter("idfinaledestination"), null);
            }

            // ───────────────────────────────────────────────────────────────
            // ACTION : updateMultiple (modifier N objets du même type)
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("updateMultiple") == 0) {
                System.out.println("miditra");   // debug
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                Page p = new Page(t, request, nombreLigne, tId);

                // Récupère N objets depuis le tableau du formulaire
                ClassMAPTable[] f = p.getObjectAvecValeurTableauUpdate();

                // ⭐ Update de masse
                u.updateObjectMultiple(f);
%>
                <script language="JavaScript">
                    document.location.replace("<%=lien%>?but=<%=bute%>");
                </script>
<%          }

            // ───────────────────────────────────────────────────────────────
            // ACTION : deleteFille (supprimer mère + filles)
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("deleteFille") == 0) {
                mere  = (ClassMAPTable) (Class.forName(classe).newInstance());
                fille = (ClassMAPTable) (Class.forName(classefille).newInstance());
                PageUpdateMultiple p = new PageUpdateMultiple(mere, fille, request, nbLine, tId);

                ClassMAPTable cmere = p.getObjectAvecValeur();
                ClassMAPTable[] cfille = p.getObjectFilleAvecValeur();

                for (int i = 0; i < cfille.length; i++) {
                    cfille[i].setNomTable(nomtable);
                }

                // ⭐ Supprime la mère ET les filles
                u.deleteObjectMultiple(cmere, cfille);
            }

            /* ═══════════════════════════════════════════════════════════════
               SECTION SPÉCIFIQUE (RH, divers)
               ═══════════════════════════════════════════════════════════════ */

            // ACTION : debaucher (module paie/RH)
            if (acte.compareToIgnoreCase("debaucher") == 0) {
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                t.setValChamp(t.getAttributIDName(), request.getParameter("idpers"));
                t.setNomTable(nomtable);
                ClassMAPTable o = (ClassMAPTable) u.createObject(t);
%>
                <script language="JavaScript">
                    document.location.replace("<%=lien%>?but=<%=bute%>");
                </script>
<%          }

            // ───────────────────────────────────────────────────────────────
            // ACTION : attacher (valider N objets en boucle)
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("attacher") == 0) {
                System.out.println("--------------- BOUTON VALIDER");
                for (int i = 0; i < tId.length; i++) {
                    System.out.println("--------------- " + tId[i]);
                    t = (ClassMAPTable) (Class.forName(classe).newInstance());
                    System.out.println("t--------------- " + t);
                    System.out.println("nomtable--------------- " + nomtable);

                    t.setValChamp(t.getAttributIDName(), tId[i]);
                    t.setNomTable(nomtable);

                    // ⭐ Valide chaque objet
                    ClassMAPTable o = (ClassMAPTable) u.validerObject(t);
                    System.out.println("VITA " + tId[i]);
                }
            }

            // ───────────────────────────────────────────────────────────────
            // ACTION : delete (supprimer UN objet)
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("delete") == 0) {
                String error = "";
                try {
                    t = (ClassMAPTable) (Class.forName(classe).newInstance());
                    t.setValChamp(t.getAttributIDName(), request.getParameter("id"));
                    if (nomtable != null && !nomtable.isEmpty()) {
                        t.setNomTable(nomtable);
                    }
                    // ⭐ DELETE en base
                    u.deleteObject(t);
                } catch (Exception e) {
%>
                    <script language="JavaScript">
                        alert('<%=e.getMessage()%>');
                        history.back();
                    </script>
<%              }
            }

            // ───────────────────────────────────────────────────────────────
            // ACTION : insertTypeObjet (nomenclature multiple)
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("insertTypeObjet") == 0) {
                String[] vals = null;
                String[] desce = null;
                String nomTable      = request.getParameter("nomtable");
                String nomProcedure  = request.getParameter("procedure");
                String startProcedure = request.getParameter("prefixe");

                if (request.getParameter("nbrLigne") != null) {
                    int taille = Utilitaire.stringToInt(request.getParameter("nbrLigne"));
                    vals  = new String[taille];
                    desce = new String[taille];
                    for (int i = 0; i < taille; i++) {
                        vals[i]  = request.getParameter("val_" + (i + 1));
                        desce[i] = request.getParameter("desce_" + (i + 1));
                    }
                }
                // ⭐ Insère N valeurs dans une nomenclature
                u.createTypeObjetMultiple(nomTable, nomProcedure, startProcedure, vals, desce);
            }

            // ───────────────────────────────────────────────────────────────
            // ACTION : insertMereLierFille (créer mère + rattacher filles existantes)
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("insertMereLierFille") == 0) {
                String error = "";
                try {
                    String[] liste_id_fille = request.getParameterValues("id");
                    String colonneFille     = request.getParameter("colonneFille");
                    String classFille       = request.getParameter("classeFille");

                    fille = (ClassFille) (Class.forName(classFille).newInstance());
                    t     = (ClassMAPTable) (Class.forName(classe).newInstance());

                    PageInsert pageInsert = new PageInsert(t, request);
                    mere = pageInsert.getObjectAvecValeur();

                    // ⭐ Crée la mère + lie les filles EXISTANTES
                    u.insertMereLierFilles((ClassMere) mere, (ClassFille) fille,
                                            liste_id_fille, colonneFille, colonneMere);
                } catch (Exception e) {
                    e.printStackTrace();
                    out.println("<script language=\"JavaScript\">alert(\"Erreur durant la validation\")</script>");
                }
            }

            // ───────────────────────────────────────────────────────────────
            // ACTION : update (modifier UN objet simple)
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("update") == 0) {
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                Page p = new Page(t, request);                  // Page simple
                ClassMAPTable f = p.getObjectAvecValeur();
                temp = f;
                if (nomtable != null) {
                    f.setNomTable(nomtable);
                }
                // ⭐ UPDATE
                u.updateObject(f);
            }

            // ───────────────────────────────────────────────────────────────
            // ACTION : dupliquer (copier un objet + ses filles)
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("dupliquer") == 0) {
                String classeFille    = request.getParameter("nomClasseFille");
                String nomColonneMere = request.getParameter("nomColonneMere");
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                t.setValChamp(t.getAttributIDName(), request.getParameter("id"));
                // ⭐ Duplique l'objet
                Object o = u.dupliquerObject(t, classeFille, nomColonneMere);
                val = o.toString();
%>
                <script language="JavaScript">
                    document.location.replace("<%=lien%>?but=<%=bute%>&id=<%=val%>");
                </script>
<%          }

            // ───────────────────────────────────────────────────────────────
            // ACTION : annuler (état → 0)
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("annuler") == 0) {
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                t.setValChamp(t.getAttributIDName(), request.getParameter("id"));
                u.annulerObject(t);
            }

            // ───────────────────────────────────────────────────────────────
            // ACTION : annulerVisa (dé-validation)
            // ⚠ C'est CE bloc qui déclenche As_BonDeCommande.annulerVisa()
            //    et donc le contrôle "impossible de dé-valider un BC validé".
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("annulerVisa") == 0) {
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                t.setValChamp(t.getAttributIDName(), request.getParameter("id"));
                temp = t;
                u.annulerVisa(t);
            }

            // ───────────────────────────────────────────────────────────────
            // ACTION : finaliser
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("finaliser") == 0) {
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                t.setValChamp(t.getAttributIDName(), request.getParameter("id"));
                temp = t;
                u.finaliser(t);
            }

            // ───────────────────────────────────────────────────────────────
            // ACTION : validerTous (valider TOUS les objets de la table)
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("validerTous") == 0) {
                ClassEtat objet = (ClassEtat) (Class.forName(classe).newInstance());
                objet.setNomTable(nomtable);
                // ⭐ Valide TOUS les objets
                u.validerObjectTous(objet);
            }

            // ═══════════════════════════════════════════════════════════════
            // ACTION : valider (valider UN objet — état 11)  ⭐
            // ═══════════════════════════════════════════════════════════════
            if (acte.compareToIgnoreCase("valider") == 0) {
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                t.setValChamp(t.getAttributIDName(), request.getParameter("id"));
                ClassMAPTable o = (ClassMAPTable) u.validerObject(t);   // ⭐ VALIDE
                temp = t;
                val = o.getTuppleID();
%>
                <script language="JavaScript">
                    document.location.replace("<%=lien%>?but=<%=bute + rajoutLie%>&id=<%=val%>");
                </script>
<%          }

            // ───────────────────────────────────────────────────────────────
            // ACTION : validerMultiple (valider N objets)
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("validerMultiple") == 0) {
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                ClassEtat[] objs = new ClassEtat[tId.length];
                for (int i = 0; i < tId.length; i++) {
                    objs[i] = (ClassEtat) Class.forName(classe).newInstance();
                    objs[i].setValChamp(t.getAttributIDName(), tId[i]);
                }
                // ⭐ Valide N objets
                u.validerObjectMultiple(objs);
%>
                <script language="JavaScript">
                    document.location.replace("<%=lien%>?but=<%=bute + rajoutLie%>&id=<%=val%>");
                </script>
<%          }

            // ───────────────────────────────────────────────────────────────
            // ACTION : deleteMultiple (supprimer N objets)
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("deleteMultiple") == 0) {
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                ClassMAPTable[] objs = new ClassMAPTable[tId.length];
                for (int i = 0; i < tId.length; i++) {
                    objs[i] = (ClassMAPTable) Class.forName(classe).newInstance();
                    objs[i].setValChamp(t.getAttributIDName(), tId[i]);
                }
                u.deleteObjectMultiple(objs);
%>
                <script language="JavaScript">
                    document.location.replace("<%=lien%>?but=<%=bute%>");
                </script>
<%          }

            // ───────────────────────────────────────────────────────────────
            // ACTION : rejeter
            // ⚠ NOTE : u.rejeterObject(t) est COMMENTÉ → ne fait RIEN !
            // C'est un bug latent signalé dans le cheat sheet.
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("rejeter") == 0) {
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                PageInsert p = new PageInsert(t, request);
                ClassMAPTable f = p.getObjectAvecValeur();
                t.setNomTable(nomtable);
                t.setValChamp(t.getAttributIDName(), request.getParameter("id"));
                //u.rejeterObject(t);   ← ⚠ COMMENTÉ, donc l'action ne fait rien
            }

            // ───────────────────────────────────────────────────────────────
            // ACTION : cloturer (état → 9)
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("cloturer") == 0) {
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                t.setValChamp(t.getAttributIDName(), request.getParameter("id"));
                u.cloturerObject(t);
            }

            // ═══════════════════════════════════════════════════════════════
            // BLOC 5 — CONSTRUCTION DES PARAMÈTRES ADDITIONNELS URL
            // ═══════════════════════════════════════════════════════════════
            if (rajoutLien != null) {
                for (int o = 0; o < rajoutLien.length; o++) {
                    String valeur = request.getParameter(rajoutLien[o]);
                    rajoutLie = rajoutLie + "&" + rajoutLien[o] + "=" + valeur;
                }
            }
%>
            <%-- ═══════════════════════════════════════════════════════════════
                 BLOC 6 — REDIRECTION FINALE (cas par défaut)

                 Pour les actes qui n'ont pas déjà fait une redirection
                 explicite (annuler, cloturer, delete…), on redirige ici
                 vers "bute" avec la valeur de retour et l'id.
                 ═══════════════════════════════════════════════════════════════ --%>
            <script language="JavaScript">
                document.location.replace("<%=lien%>?but=<%=bute + rajoutLie%>&valeur=<%=val%>&id=<%=id%>");
            </script>
<%
        } catch (Exception ex) {
            // ═══════════════════════════════════════════════════════════════
            // BLOC 7 — CATCH FINAL (pattern APJ standard)
            // Toute exception → alerte JS + retour arrière
            // ═══════════════════════════════════════════════════════════════
            ex.printStackTrace();
%>
            <script type="text/javascript">
                alert("<%=ex.getMessage()%>");
                history.back();
            </script>
<%
            return;
        }
%>
</html>