<%--
  apresTarif.jsp — Moteur d'actions SIMPLE (1 seul objet)

  RÔLE :
  Comme apresMultiple.jsp, mais pour UN SEUL objet (pas de mère/fille).
  C'est lui qui est appelé quand tu cliques sur :
     - Viser (valider)
     - Modifier (update)
     - Annuler (annuler)
     - Supprimer (delete)
     - Clôturer
     - Payer

  DIFFÉRENCE avec apresMultiple.jsp :
     apresMultiple → gère mère + filles (N lignes)
     apresTarif    → gère un seul objet (1 ligne)

  Sur ta fiche BC, les boutons Viser/Annuler pointent ICI :
     ...?but=apresTarif.jsp&acte=valider&id=BC001&bute=...fiche.jsp&classe=...
--%>

<%-- ═══════════════════════════════════════════════════════════════
     BLOC 0 — IMPORTS
     ═══════════════════════════════════════════════════════════════ --%>
<%@ page pageEncoding="UTF-8" contentType="text/html; charset=UTF-8" %>
<%@page import="historique.MapUtilisateur"%>       <%-- Pour insertUser --%>
<%@page import="java.util.List"%>
<%@ page import="user.*" %>                          <%-- UserEJB --%>
<%@ page import="produits.*" %>                      <%-- Ingredients --%>
<%@ page import="utilitaire.*" %>                    <%-- Utilitaire, ValidationException --%>
<%@ page import="bean.*" %>                          <%-- ClassMAPTable, ClassFille, ClassMere --%>
<%@ page import="java.sql.SQLException" %>
<%@ page import="affichage.*" %>                     <%-- PageInsert, Page --%>
<%@ page import="caisse.MvtCaisse" %>                <%-- Pour validerMvt --%>
<%@ page import="maintenance.planning.Planning" %>   <%-- Pour insertPlanning --%>

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>

    <%-- ═══════════════════════════════════════════════════════════════
         BLOC 1 — VARIABLES DE CLASSE
         ⚠ <%! ... %> = variables d'instance JSP (comme apresMultiple)
         ═══════════════════════════════════════════════════════════════ --%>
    <%!
        UserEJB u = null;
        String acte = null;
        String lien = null;
        String bute;
        String nomtable = null;
        String typeBoutton;
        String champReturn;
        String action = null;
    %>

    <%
        try {
            // ═══════════════════════════════════════════════════════════════
            // BLOC 2 — LECTURE DES PARAMÈTRES DU POST/GET
            // ═══════════════════════════════════════════════════════════════
            nomtable    = request.getParameter("nomtable");
            typeBoutton = request.getParameter("type");
            lien        = (String) session.getValue("lien");
            u           = (UserEJB) session.getAttribute("u");
            acte        = request.getParameter("acte");          // ⭐ l'action
            bute        = request.getParameter("bute");          // où rediriger
            action      = request.getParameter("action");        // action secondaire
            Object temp = null;
            String[] rajoutLien = null;
            String classe = request.getParameter("classe");      // ⭐ FQN de la classe
            ClassMAPTable t = null;
            String tempRajout = request.getParameter("rajoutLien");
            String val = "";
            String id = request.getParameter("id");              // id de l'objet
            champReturn = request.getParameter("champReturn");

            // Gestion des paramètres additionnels URL "p1-p2-p3"
            String rajoutLie = "";
            if (tempRajout != null && tempRajout.compareToIgnoreCase("") != 0) {
                rajoutLien = utilitaire.Utilitaire.split(tempRajout, "-");
            }

            // Paramètre additionnel spécifique au FORMULAIRE (rajoutLienFormu)
            String tempRajoutLienFormu = request.getParameter("rajoutLienFormu");
            String rajoutLieFormu = "";
            String[] rajoutLienFormu = null;
            if (tempRajoutLienFormu != null && tempRajoutLienFormu.compareToIgnoreCase("") != 0) {
                rajoutLienFormu = utilitaire.Utilitaire.split(tempRajoutLienFormu, "-");
                if (rajoutLienFormu.length == 2) {
                    rajoutLieFormu = "&" + rajoutLienFormu[0] + "=" + rajoutLienFormu[1];
                }
            }

            // ═══════════════════════════════════════════════════════════════
            // BLOC 3 — INSTANCIATION PAR RÉFLEXION
            // ⭐ Même mécanisme qu'apresMultiple.jsp
            // ═══════════════════════════════════════════════════════════════
            ClassMAPTable classTemp = (ClassMAPTable) (Class.forName(classe).newInstance());

            // ⭐ Si "insert" ET que l'id existe déjà → c'est un UPDATE
            // ⚠ Note : ici c'est "update" (pas "updateInsert" comme dans apresMultiple)
            if (acte.equalsIgnoreCase("insert")
                && request.getParameter(classTemp.getAttributIDName()) != null
                && !request.getParameter(classTemp.getAttributIDName()).isEmpty()) {
                acte = "update";
            }

            String acteDetail = request.getParameter("acteDetail");

            if (typeBoutton == null || typeBoutton.compareToIgnoreCase("") == 0) {
                typeBoutton = "3";
            }

            // Construction des paramètres additionnels URL
            if (rajoutLien != null) {
                for (int o = 0; o < rajoutLien.length; o++) {
                    String valeur = request.getParameter(rajoutLien[o]);
                    rajoutLie = rajoutLie + "&" + rajoutLien[o] + "=" + valeur;
                }
            }

            // Si champUrl → redirection vers une popup
            String champUrl = request.getParameter("champUrl");
            if (champUrl != null) {
                bute = "popup/apresPopup.jsp";
            }

            int type = Utilitaire.stringToInt(typeBoutton);

            // ═══════════════════════════════════════════════════════════════
            // BLOC 4 — LES ACTIONS
            // ═══════════════════════════════════════════════════════════════

            // ───────────────────────────────────────────────────────────────
            // ACTION : insertMenu (ajouter un menu à un utilisateur)
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("insertMenu") == 0) {
                String utilisateur = request.getParameter("refuser");
                String menu        = request.getParameter("idmenu");
                String acces       = request.getParameter("interdit");
                u.ajouterMenuUtilisateur(utilisateur, menu, null, acces);
            }

            // ───────────────────────────────────────────────────────────────
            // ACTION : insertPlanning (cas spécial planning maintenance)
            // Si nomtable = "Planning" et qu'il y a des jours cochés
            // → bascule sur insertPlanning et génère le planning semaine
            // ───────────────────────────────────────────────────────────────
            String[] jours = request.getParameterValues("jours");
            if (acte != null && acte.compareToIgnoreCase("insert") == 0
                && nomtable != null && nomtable.equalsIgnoreCase("Planning")
                && jours != null) {
                acte = "insertPlanning";
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                PageInsert p = new PageInsert(t, request);
                ClassMAPTable f = p.getObjectAvecValeur();
                f.setNomTable(nomtable);
                Planning plan = (Planning) f;
                plan.genererPlanningSemaine(jours, u.getUser().getTuppleID());
                bute = "maintenance/planning/calendrier-maintenance.jsp&currentMenu=MNDNMT0124";
%>
                <script language="JavaScript">
                    document.location.replace("<%=lien%>?but=<%=bute%>")
                </script>
<%          }

            // ═══════════════════════════════════════════════════════════════
            // ACTION : insert  (CRÉER un objet simple)
            // ═══════════════════════════════════════════════════════════════
            if (acte.compareToIgnoreCase("insert") == 0) {
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                PageInsert p = new PageInsert(t, request);            // ⭐ PageInsert simple
                ClassMAPTable f = p.getObjectAvecValeur();
                f.setNomTable(nomtable);
                ClassMAPTable o = (ClassMAPTable) u.createObject(f);  // ⭐ INSERT
                temp = (Object) o;
                if (o != null) {
                    id = o.getTuppleID();
                }
            }

            // ───────────────────────────────────────────────────────────────
            // ACTION : insertWithAction (insertion avec action personnalisée)
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("insertWithAction") == 0) {
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                PageInsert p = new PageInsert(t, request);
                ClassMAPTable f = p.getObjectAvecValeur();
                f.setNomTable(nomtable);
                ClassMAPTable o = (ClassMAPTable) u.createObject(f, action);  // ⭐ action en plus
                temp = (Object) o;
                if (o != null) {
                    id = o.getTuppleID();
                }
            }

            // ───────────────────────────────────────────────────────────────
            // ACTION : dupliquer (copier un objet)
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("dupliquer") == 0) {
                String classeFille    = request.getParameter("nomClasseFille");
                String nomColonneMere = request.getParameter("nomColonneMere");
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                t.setValChamp(t.getAttributIDName(), request.getParameter("id"));
                if (request.getAttribute("nomtable") != null) {
                    nomtable = (String) request.getAttribute("nomtable");
                }
                if (nomtable != null && nomtable.compareToIgnoreCase("") != 0
                    && nomtable.compareToIgnoreCase("null") != 0) {
                    t.setNomTable(nomtable);
                }
                val = (String) u.dupliquerObject(t, classeFille, nomColonneMere);
                bute += "&nomtable=" + t.getNomTable();
%>
                <script language="JavaScript">
                    document.location.replace("<%=lien%>?but=<%=bute + rajoutLie%>&id=<%=val%>");
                </script>
<%          }

            // ───────────────────────────────────────────────────────────────
            // ACTION : insertUser (créer un utilisateur)
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("insertUser") == 0) {
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                PageInsert p = new PageInsert(t, request);
                ClassMAPTable f = p.getObjectAvecValeur();
                f.setNomTable(nomtable);
                MapUtilisateur util = (MapUtilisateur) f;
                // ⭐ Méthode spéciale pour créer un utilisateur (chiffre le mot de passe)
                id = u.createUtilisateurs(
                    util.getLoginuser(), util.getPwduser(), util.getNomuser(),
                    util.getAdruser(), util.getTeluser(), util.getIdrole()
                );
%>
                <script language="JavaScript">
                    document.location.replace("<%=lien%>?but=<%=bute + rajoutLie%>&refuser=<%=Utilitaire.champNull(id)%>");
                </script>
<%          }

            // ═══════════════════════════════════════════════════════════════
            // ACTION : savevalider (créer PUIS valider en 1 clic)
            // ═══════════════════════════════════════════════════════════════
            if (acte.compareToIgnoreCase("savevalider") == 0) {
                PageInsert p = new PageInsert(t, request);
                ClassMAPTable f = p.getObjectAvecValeur();
                f.setNomTable(nomtable);
                ClassMAPTable o = (ClassMAPTable) u.createObject(f);   // INSERT
                temp = (Object) o;
                if (o != null) {
                    id = o.getTuppleID();
                }

                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                t.setValChamp(t.getAttributIDName(), request.getParameter("id"));
                t.setNomTable(nomtable);
                ClassMAPTable ov = (ClassMAPTable) u.validerObject(t);  // ⭐ VALIDE
                temp = t;
                val = o.getTuppleID();
%>
                <script language="JavaScript">
                    document.location.replace("<%=lien%>?but=<%=bute + rajoutLie%>&id=<%=val%>");
                </script>
<%          }

            // ═══════════════════════════════════════════════════════════════
            // ACTION : deleteFille (supprimer une fille)
            // ═══════════════════════════════════════════════════════════════
            if (acte.compareToIgnoreCase("deleteFille") == 0) {
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                t.setValChamp(t.getAttributIDName(), request.getParameter("id"));
                temp = (Object) t;
                u.deleteObjetFille(t);   // ⭐ Supprime UNE fille
            }

            // ═══════════════════════════════════════════════════════════════
            // ACTION : delete (supprimer un objet simple)
            // ═══════════════════════════════════════════════════════════════
            if (acte.compareToIgnoreCase("delete") == 0) {
                String error = "";
                try {
                    t = (ClassMAPTable) (Class.forName(classe).newInstance());
                    t.setValChamp(t.getAttributIDName(), request.getParameter("id"));
                    if (nomtable != null && !nomtable.isEmpty()) {
                        t.setNomTable(nomtable);
                    }
                    u.deleteObject(t);   // ⭐ DELETE

                    // Cas spécial : si c'est une commande, rediriger vers la mère
                    if (classe.compareToIgnoreCase("commande.Commande") == 0) {
%>
                        <script language="JavaScript">
                            document.location.replace("<%=lien%>?but=<%=bute%>&id=<%=request.getParameter("idmere")%>");
                        </script>
<%
                    } else {
%>
                        <script language="JavaScript">
                            document.location.replace("<%=lien%>?but=<%=bute + rajoutLie + rajoutLieFormu%>");
                        </script>
<%
                    }
                } catch (Exception e) {
%>
                    <script language="JavaScript">
                        alert('<%=e.getMessage()%>');
                        history.back();
                    </script>
<%              }
            }

            // ═══════════════════════════════════════════════════════════════
            // ACTION : update (MODIFIER un objet simple)
            // ═══════════════════════════════════════════════════════════════
            if (acte.compareToIgnoreCase("update") == 0) {
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                Page p = new Page(t, request);                        // ⭐ Page (pas PageInsert)
                ClassMAPTable f = p.getObjectAvecValeur();
                temp = f;
                if (nomtable != null) {
                    f.setNomTable(nomtable);
                }
                u.updateObject(f);   // ⭐ UPDATE
                id = f.getTuppleID();
            }

            // ───────────────────────────────────────────────────────────────
            // ACTION : updateMvt (modifier + valider un mouvement de caisse)
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("updateMvt") == 0) {
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                Page p = new Page(t, request);
                ClassMAPTable f = p.getObjectAvecValeur();
                temp = f;
                if (nomtable != null) f.setNomTable(nomtable);
                u.updateObject(f);        // UPDATE
                u.validerObject(t);       // puis VALIDE
                id = f.getTuppleID();
            }

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
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("annulerVisa") == 0) {
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                t.setValChamp(t.getAttributIDName(), request.getParameter("id"));
                temp = t;
                if (request.getAttribute("nomtable") != null) {
                    nomtable = (String) request.getAttribute("nomtable");
                }
                if (nomtable != null && nomtable.compareToIgnoreCase("") != 0
                    && nomtable.compareToIgnoreCase("null") != 0) {
                    t.setNomTable(nomtable);
                }
                u.annulerVisa(t);   // ⭐ Dé-validation
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
            // ACTION : updatevalider (modifier PUIS valider)
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("updatevalider") == 0) {
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                Page p = new Page(t, request);
                ClassMAPTable f = p.getObjectAvecValeur();
                temp = f;
                if (nomtable != null) f.setNomTable(nomtable);
                u.updateObject(f);        // UPDATE
                u.validerObject(t);       // puis VALIDE
                id = f.getTuppleID();
            }

            // ───────────────────────────────────────────────────────────────
            // ACTION : insertMereLierFille (créer mère + lier filles existantes)
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("insertMereLierFille") == 0) {
                String error = "";
                try {
                    String[] liste_id_fille = request.getParameterValues("ids");
                    String colonneMere   = request.getParameter("colonneMere");
                    String colonneFille  = request.getParameter("colonneFille");
                    String classFille    = request.getParameter("classeFille");

                    ClassFille fille = (ClassFille) (Class.forName(classFille).newInstance());
                    t = (ClassMAPTable) (Class.forName(classe).newInstance());
                    PageInsert pageInsert = new PageInsert(t, request);
                    ClassMAPTable mere = pageInsert.getObjectAvecValeur();
                    u.insertMereLierFilles((ClassMere) mere, fille, liste_id_fille,
                                            colonneFille, colonneMere);
                } catch (Exception e) {
                    e.printStackTrace();
                    out.println("<script language=\"JavaScript\">alert(\"Erreur durant la validation\")</script>");
                }
            }

            // ═══════════════════════════════════════════════════════════════
            // ACTION : valider (état → 11)  ⭐ C'EST LE "VISER"
            // ═══════════════════════════════════════════════════════════════
            if (acte.compareToIgnoreCase("valider") == 0) {
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                t.setValChamp(t.getAttributIDName(), request.getParameter("id"));
                if (nomtable != null && nomtable.compareToIgnoreCase("") != 0)
                    t.setNomTable(nomtable);
                ClassMAPTable o = (ClassMAPTable) u.validerObject(t);   // ⭐ VALIDE
                temp = t;
                val = o.getTuppleID();
%>
                <script language="JavaScript">
                    document.location.replace("<%=lien%>?but=<%=bute + rajoutLie%>&id=<%=val%>");
                </script>
<%          }

            // ───────────────────────────────────────────────────────────────
            // ACTION : validerMvt (valider un mouvement de caisse)
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("validerMvt") == 0) {
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                t.setValChamp(t.getAttributIDName(), request.getParameter("id"));
                if (nomtable != null && nomtable.compareToIgnoreCase("") != 0)
                    t.setNomTable(nomtable);
                MvtCaisse caisse = (MvtCaisse) t;                        // ⭐ Cast spécifique
                ClassMAPTable o = caisse.validerSimple(u.getUser().getTuppleID(), null);
                temp = t;
                val = o.getTuppleID();
%>
                <script language="JavaScript">
                    document.location.replace("<%=lien%>?but=<%=bute + rajoutLie%>&id=<%=val%>");
                </script>
<%          }

            // ───────────────────────────────────────────────────────────────
            // ACTION : cloturer (état → 9)
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("cloturer") == 0) {
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                t.setValChamp(t.getAttributIDName(), request.getParameter("id"));
                if (nomtable != null && !nomtable.isEmpty()) {
                    t.setNomTable(nomtable);
                }
                u.cloturerObject(t);
            }

            // ───────────────────────────────────────────────────────────────
            // ACTION : payer
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("payer") == 0) {
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                t.setValChamp(t.getAttributIDName(), request.getParameter("id"));
                if (nomtable != null && !nomtable.isEmpty()) {
                    t.setNomTable(nomtable);
                }
                ClassMAPTable o = (ClassMAPTable) u.payerObject(t);   // ⭐ PAIEMENT
                if (t != null) {
                    id = o.getTuppleID();
                }
            }

            // ───────────────────────────────────────────────────────────────
            // ACTION : custom (changement d'état personnalisé)
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("custom") == 0) {
                t = (ClassMAPTable) (Class.forName(classe).newInstance());
                t.setValChamp(t.getAttributIDName(), id);
                t.setNomTable(nomtable);
                u.changeState(t, acteDetail);   // ⭐ état personnalisé
            }

            // ───────────────────────────────────────────────────────────────
            // ACTION : disponible (rendre un produit disponible/indisponible)
            // ───────────────────────────────────────────────────────────────
            if (acte.compareToIgnoreCase("disponible") == 0) {
                Ingredients ing = new Ingredients();
                String idProduit = request.getParameter("id");
                String dispo     = request.getParameter("isdispo");
                ing.produitDisponible(idProduit, dispo, u.getUser().getTuppleID());
                bute = "produits/as-ingredients-fiche.jsp&id=" + idProduit;
            }

            // ═══════════════════════════════════════════════════════════════
            // BLOC 5 — REDIRECTION FINALE (par défaut)
            // ═══════════════════════════════════════════════════════════════
            String idAttributeName = "id";
            if (t != null && t.getAttributIDName() != null && !t.getAttributIDName().trim().isEmpty())
                idAttributeName = t.getAttributIDName();
%>
            <script language="JavaScript">
                document.location.replace("<%=lien%>?but=<%=bute + rajoutLie%>&valeur=<%=val%>&<%=idAttributeName%>=<%=Utilitaire.champNull(id)%>");
            </script>
<%
        } catch (ValidationException validation) {
            // ═══════════════════════════════════════════════════════════════
            // BLOC 6 — CAS SPÉCIAL : ValidationException
            // Si l'objet lance une ValidationException, on propose à
            // l'utilisateur de forcer la validation ("Valider FF").
            // ═══════════════════════════════════════════════════════════════
%>
            <script language="JavaScript">
                var result = confirm("<%= validation.getMessageavalider() %>");
                if (result) {
                    document.location.replace("<%=lien%>?but=apresTarif.jsp&id=<%=Utilitaire.champNull(request.getParameter("id"))%>&bute=<%=bute%>&acte=validerFF&classe=facture.FactureFournisseur");
                } else {
                    history.back();
                }
            </script>
<%
        } catch (Exception e) {
            // ═══════════════════════════════════════════════════════════════
            // BLOC 7 — CATCH FINAL (pattern APJ)
            // ═══════════════════════════════════════════════════════════════
            e.printStackTrace();
%>
            <script language="JavaScript">
                alert("<%= new String(e.getMessage().getBytes(), "UTF-8") %>");
                history.back();
            </script>
<%
            return;
        }
%>
</html>