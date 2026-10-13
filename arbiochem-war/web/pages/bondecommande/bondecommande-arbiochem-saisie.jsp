<%--
  Écran ACTIF de saisie d'un Bon de Commande Fournisseur (version ARBIOCHEM)
  Créé par Tsinjoniaina le 10/08/2026

  Rôle : créer (ou modifier) un BC fournisseur = 1 en-tête + N lignes de produits.
  Techno : PageInsertMultiple (APJ) + calculs JS du total TTC.

  ⚠ RÈGLE : ne jamais corriger la version générique bondecommande-saisie.jsp,
  elle n'est JAMAIS vue par les utilisateurs. Celle-ci est la seule active.
--%>

<%-- ═══════════════════════════════════════════════════════════
     BLOC 0 — IMPORTS
     Comme en Java : sans import, les classes ne sont pas reconnues.
     Les 4 imports "piliers" APJ sont : user.*, affichage.*,
     utilitaire.*, et le package métier du module.
     ═══════════════════════════════════════════════════════════ --%>
<%@page import="user.*"%>                          <%-- UserEJB : l'utilisateur connecté --%>
<%@page import="affichage.*"%>                     <%-- PageInsertMultiple, Liste, Champ... --%>
<%@page import="utilitaire.*"%>                    <%-- Utilitaire, ConstanteEtat, UtilDB --%>
<%@page import="faturefournisseur.*"%>             <%-- As_BonDeCommande, Fournisseur... --%>
<%@ page import="magasin.Magasin" %>               <%-- La table MAGASIN2 --%>
<%@ page import="mg.cnaps.compta.ConstanteCompta" %><%-- Pour ConstanteCompta.constante_tva --%>
<%@ page import="prevision.Service" %>             <%-- (import non utilisé ici) --%>
<%@ page import="bean.TypeObjet" %>                <%-- Pour TypeObjet("DEPARTEMENT") --%>

<%
    try {
        // ═══════════════════════════════════════════════════════════
        // BLOC 1 — RÉCUPÉRATION DE L'UTILISATEUR CONNECTÉ
        // session.getValue("u") est LA façon APJ (pas getAttribute).
        // L'utilisateur a été mis en session par testLogin.jsp.
        // ═══════════════════════════════════════════════════════════
        UserEJB u = null;
        u = (UserEJB) session.getValue("u");

        // ═══════════════════════════════════════════════════════════
        // BLOC 2 — CRÉATION DE LA PAGE MÈRE + FILLE
        //
        // mere  = 1 enregistrement (l'en-tête du BC)
        // fille = N lignes (les produits du BC)
        //
        // PageInsertMultiple = LE moteur APJ pour un formulaire
        //   mère+fille. Elle gère :
        //   - l'affichage des champs de l'en-tête
        //   - le tableau du détail avec N lignes
        //   - le POST vers apresMultiple.jsp
        // ═══════════════════════════════════════════════════════════
        As_BonDeCommande       mere  = new As_BonDeCommande();
        As_BonDeCommande_Fille fille = new As_BonDeCommande_Fille();

        // ⚠ La fille lit/écrit dans une VUE "_CPL" (complétée avec libellés)
        // au lieu de la table brute. C'est ce qui permet d'afficher
        // produitLib, comptelibelle, etc. dans le tableau.
        fille.setNomTable("AS_BONDECOMMANDE_FILLE_CPL");

        // Nombre de lignes vides affichées dans le tableau détail
        int nombreLigne = 10;

        // Instanciation du moteur : (mere, fille, request, N, user)
        PageInsertMultiple pi = new PageInsertMultiple(mere, fille, request, nombreLigne, u);

        // Lien de base (module.jsp) pour la redirection après POST
        pi.setLien((String) session.getValue("lien"));

        // ═══════════════════════════════════════════════════════════
        // BLOC 3 — LES 4 LISTES DÉROULANTES DE L'EN-TÊTE
        //
        // Syntaxe : new Liste("nomChamp", objetSource, "colonneAffichée", "colonneStockée")
        // ═══════════════════════════════════════════════════════════
        Liste[] liste = new Liste[4];

        // --- Liste 0 : Devise (AR / USD / EUR) ---
        caisse.Devise dev = new caisse.Devise();
        liste[0] = new Liste("idDevise", dev, "val", "id");
        liste[0].setDefaut("AR");                       // valeur par défaut = Ariary

        // --- Liste 1 : Mode de paiement ---
        ModePaiement mp = new ModePaiement();
        liste[1] = new Liste("modepaiement", mp, "val", "id");

        // --- Liste 2 : Magasin (⚠ source = MAGASIN2, pas MAGASIN) ---
        Magasin magasin = new Magasin();
        magasin.setNomTable("MAGASIN2");
        liste[2] = new Liste("idMagasin", magasin, "val", "id");
        // ⭐ Filtre SQL : ne propose que les magasins actifs.
        // Le " and ..." doit commencer par "and" car APJ ajoute déjà un WHERE.
        liste[2].setApresW(" and actif = 1");

        // --- Liste 3 : Département (via nomenclature générique TypeObjet) ---
        liste[3] = new Liste("service", new TypeObjet("DEPARTEMENT"), "val", "id");
        liste[3].setApresW(" and Actif = 1");           // idem : filtre actifs

        // Applique les 4 listes : transforme les <input> en <select>
        pi.getFormu().changerEnChamp(liste);

        // ═══════════════════════════════════════════════════════════
        // BLOC 4 — LIBELLÉS DE L'EN-TÊTE
        // Syntaxe : pi.getFormu().getChamp("x").setLibelle("...")
        // ═══════════════════════════════════════════════════════════
        pi.getFormu().getChamp("service").setLibelle("D&eacute;partement");
        pi.getFormu().getChamp("modepaiement").setLibelle("Mode de paiement");
        pi.getFormu().getChamp("idMagasin").setLibelle("Magasin");
        pi.getFormu().getChamp("etat").setVisible(false);   // caché (géré par le workflow)
        pi.getFormu().getChamp("reference").setLibelle("R&eacute;f&eacute;rence");
        pi.getFormu().getChamp("designation").setLibelle("D&eacute;signation");
        pi.getFormu().getChamp("remarque").setLibelle("Remarque");
        pi.getFormu().getChamp("daty").setLibelle("Date");
        pi.getFormu().getChamp("dateLimite").setLibelle("Date limite de livraison");
        pi.getFormu().getChamp("fournisseur").setLibelle("Fournisseur");

        // --- Autocomplétion FOURNISSEUR (avec filtre estActif = 1) ---
        // Syntaxe : setPageAppelCompleteAWhere(classe, colAff, libellé, colFiltre, colRetour, where)
        pi.getFormu().getChamp("fournisseur")
           .setPageAppelCompleteAWhere(
               "faturefournisseur.Fournisseur",   // classe Java source
               "id",                               // colonne affichée
               "Fournisseur",                      // libellé
               "taxe",                             // colonne filtre
               "taxe",                             // colonne retour (remplit aussi "taxe")
               " and estActif = 1"                 // ⭐ filtre
           );

        // --- Bouton "+" : créer un fournisseur à la volée ---
        // setPageAppelInsert(page, colonnesLues, colonnesRetour)
        pi.getFormu().getChamp("fournisseur")
           .setPageAppelInsert(
               "fournisseur/fournisseur-saisie.jsp",  // popup de saisie
               "fournisseur;fournisseurlibelle",       // ce qu'on lit du popup
               "id;nom"                                // ce qui revient ici
           );

        pi.getFormu().getChamp("idDevise").setLibelle("Devise");
        pi.getFormu().getChamp("iddmdachat").setLibelle("Demande d'achat");

        // Le champ "remise" (en-tête) déclenche le recalcul du total au change
        pi.getFormu().getChamp("remise").setAutre("onchange='calculerMontantV2()'");

        pi.getFormu().getChamp("refproforma").setLibelle("R&eacute;f&eacute;rence proforma");

        // ═══════════════════════════════════════════════════════════
        // BLOC 5 — GESTION DU CHAMP "iddmdachat" (demande d'achat)
        // Si on arrive avec ?iddmdachat=XXX dans l'URL → readonly + préremplissage.
        // Sinon → autocomplétion normale sur la table DMDACHAT.
        // ═══════════════════════════════════════════════════════════
        if (request.getParameter("iddmdachat") != null) {
            pi.getFormu().getChamp("iddmdachat").setDefaut(request.getParameter("iddmdachat"));
            pi.getFormu().getChamp("iddmdachat").setAutre("readonly");
        } else {
            pi.getFormu().getChamp("iddmdachat")
               .setPageAppelComplete("faturefournisseur.DmdAchat", "id", "DMDACHAT", "id", "id");
        }

        // Quand on change la devise → JS "deviseModification()" recharge l'autocomplétion produit
        pi.getFormu().getChamp("idDevise").setAutre("onChange='deviseModification()'");

        // ═══════════════════════════════════════════════════════════
        // BLOC 6 — AUTOCOMPLÉTION PRODUIT (DÉTAIL / FILLE)
        //
        // ⚠ Différence avec l'en-tête :
        //   - setPageAppelComplete (statique, sur un TABLEAU de champs)
        //     prend une TABLE/VUE SQL comme source : ici AS_INGREDIENTS_LIB_ACHAT
        //   - setPageAppelCompleteAWhere (sur un champ)
        //     prend une CLASSE Java comme source
        //
        // Mapping "a;b;c" → "x;y;z" :
        //   à la sélection, APJ prend les colonnes de la VUE et les injecte
        //   dans les champs du formulaire, DANS LE MÊME ORDRE.
        // ═══════════════════════════════════════════════════════════
        affichage.Champ.setPageAppelComplete(
            pi.getFormufle().getChampFille("produit"),     // le champ à équiper
            "produits.IngredientsLib",                      // classe Java
            "id",                                            // colonne affichée
            "AS_INGREDIENTS_LIB_ACHAT",                      // ⭐ TABLE/VUE source
            "pu;taux;compte_achat;compte_achat;libelle",     // colonnes LUES dans la vue
            "pu;tauxDeChange;compte;comptelibelle;produitLib"// champs REMPLIS ici
        );

        // Bouton "+" pour créer un produit à la volée
        affichage.Champ.setPageAppelInsert(
            pi.getFormufle().getChampFille("produit"),
            "produits/as-ingredients-saisie.jsp",
            "id;libelle"
        );

        // ═══════════════════════════════════════════════════════════
        // BLOC 7 — LIBELLÉS DU DÉTAIL (ligne 0 seulement pour l'exemple)
        //
        // ⚠ getChamp("x_0") = UNE SEULE ligne (la 0)
        //    getChampMulitple("x") = TOUTES les lignes d'un coup
        // ═══════════════════════════════════════════════════════════
        pi.getFormufle().getChamp("produit_0").setLibelle("Produit");
        pi.getFormufle().getChamp("produitLib_0").setLibelle("D&eacute;signation");
        pi.getFormufle().getChamp("tva_0").setLibelle("TVA (%)");
        pi.getFormufle().getChamp("remise_0").setLibelle("Remise (%)");
        pi.getFormufle().getChamp("quantite_0").setLibelle("Quantit&eacute;");
        pi.getFormufle().getChamp("pu_0").setLibelle("Prix Unitaire HT");
        pi.getFormufle().getChamp("idDevise_0").setLibelle("Devise");

        // Colonnes techniques cachées sur TOUTES les lignes
        pi.getFormufle().getChampMulitple("id").setVisible(false);        // PK
        pi.getFormufle().getChampMulitple("idbc").setVisible(false);      // FK vers la mère
        pi.getFormufle().getChampMulitple("montant").setVisible(false);   // calculé
        pi.getFormufle().getChampMulitple("unite").setVisible(false);     // non utilisé ici
        pi.getFormufle().getChampMulitple("idDevise").setVisible(false);  // caché (rempli par JS)

        pi.getFormufle().getChamp("tauxDeChange_0").setLibelle("Taux de change");

        // ═══════════════════════════════════════════════════════════
        // BLOC 8 — onchange JS SUR TOUTES LES LIGNES DU DÉTAIL
        // setAutre(champs[], "html brut") → injecte l'attribut HTML
        // sur CHAQUE champ de la liste. Ici : recalculer à chaque change.
        // ═══════════════════════════════════════════════════════════
        affichage.Champ.setAutre(pi.getFormufle().getChampFille("pu"),       "onchange='calculerMontantV2()'");
        affichage.Champ.setAutre(pi.getFormufle().getChampFille("quantite"), "onchange='calculerMontantV2()'");
        affichage.Champ.setAutre(pi.getFormufle().getChampFille("tva"),      "onchange='calculerMontantV2()'");
        affichage.Champ.setAutre(pi.getFormufle().getChampFille("produit"),  "onchange='calculerMontantV2()'");

        // ═══════════════════════════════════════════════════════════
        // BLOC 9 — PRÉPARATION ⚠ LIGNE CRUCIALE
        //
        // preparerDataFormu() :
        //   1. lit les paramètres du request (pré-remplissage)
        //   2. CONSTRUIT la structure HTML des 10 lignes du détail
        //   3. DOIT être appelée AVANT toute boucle getChamp("x_"+i)
        //      sinon les champs _0, _1... n'existent pas encore.
        // ═══════════════════════════════════════════════════════════
        pi.preparerDataFormu();

        // Boucle sur les 10 lignes pour appliquer des réglages INDIVIDUELS
        for (int i = 0; i < nombreLigne; i++) {
            pi.getFormufle().getChamp("idDevise_" + i).setAutre("readonly");
            pi.getFormufle().getChamp("quantite_" + i).setAutre("onChange='calculerMontantV2(" + i + ")'");
            pi.getFormufle().getChamp("remise_" + i).setAutre("onChange='calculerMontantV2(" + i + ")'");
            pi.getFormufle().getChamp("tva_" + i).setAutre("onChange='calculerMontantV2(" + i + ")'");
            pi.getFormufle().getChamp("quantite_" + i).setDefaut("0");
            pi.getFormufle().getChamp("tva_" + i).setDefaut("0");
            pi.getFormufle().getChamp("idDevise_" + i).setDefaut("AR");
            pi.getFormufle().getChamp("tauxDeChange_" + i).setDefaut("1");
        }

        // ═══════════════════════════════════════════════════════════
        // BLOC 10 — PRÉ-REMPLISSAGE DEPUIS UNE DEMANDE D'ACHAT
        //
        // Si on arrive avec ?iddmdachat=XXX :
        //   - on charge la DmdAchat
        //   - on copie ses valeurs dans l'en-tête
        //   - on transforme ses lignes en lignes du BC (setDefautFille)
        // ═══════════════════════════════════════════════════════════
        String iddmdachat = request.getParameter("iddmdachat");
        if (iddmdachat != null && !iddmdachat.isEmpty()) {
            DmdAchat dmdAchat = (DmdAchat) new DmdAchat().getById(iddmdachat, "DMDACHAT", null);
            if (dmdAchat != null) {
                pi.getFormu().getChamp("daty").setDefaut(Utilitaire.datetostring(dmdAchat.getDaty()));
                pi.getFormu().getChamp("fournisseur").setDefaut(dmdAchat.getFournisseur());
                pi.getFormu().getChamp("designation").setDefaut("bon de commande de la demande d'achat " + iddmdachat);
                pi.getFormu().getChamp("idMagasin").setDefaut(dmdAchat.getIdMagasin());
                pi.getFormu().getChamp("service").setDefaut(dmdAchat.getService());

                if (dmdAchat.getDateLimite() != null) {
                    pi.getFormu().getChamp("dateLimite").setDefaut(Utilitaire.datetostring(dmdAchat.getDateLimite()));
                }

                // Récupère les lignes de la demande d'achat transformées en lignes de BC
                As_BonDeCommande_Fille[] bcFille = dmdAchat.getBonDeCommandeDetails(null);
                As_BonDeCommande_Fille[] nouvellebcFille =
                    DmdAchatSuiviCommande.updateResterCommandeQuantite(bcFille, iddmdachat);

                System.out.println("qte aff = " + bcFille[0].getQuantite()); // debug

                // ⭐ Injecte ces lignes dans le tableau détail
                pi.setDefautFille(nouvellebcFille);
            }
        }

        // ═══════════════════════════════════════════════════════════
        // BLOC 11 — VARIABLES DE NAVIGATION
        // Ces 4 variables seront injectées en <input type="hidden"> dans
        // le <form>. C'est LE CONTRAT avec apresMultiple.jsp.
        // ═══════════════════════════════════════════════════════════
        String classeMere   = "faturefournisseur.As_BonDeCommande";        // FQN de la mère
        String classeFille  = "faturefournisseur.As_BonDeCommande_Fille";  // FQN de la fille
        String butApresPost = "bondecommande/bondecommande-arbiochem-fiche.jsp"; // ⭐ où rediriger
        String colonneMere  = "idbc";                                       // FK fille → mère

        // Ordre des colonnes dans le tableau détail
        pi.getFormufle().setColOrdre(new String[]{
            "produit", "produitLib", "quantite", "pu", "tva", "remise", "tauxDeChange"
        });

        // Génère les ordres de tabulation (accessibilité clavier)
        pi.getFormu().makeHtmlInsertTabIndex();
        pi.getFormufle().makeHtmlInsertTableauIndex();

%>
<%-- ═══════════════════════════════════════════════════════════
     PARTIE HTML — Le rendu visuel
     ═══════════════════════════════════════════════════════════ --%>
<div class="content-wrapper">

    <%-- Titre dynamique : "Modification" si ?acte=update, sinon "Saisie" --%>
    <% if (request.getParameter("acte") != null
           && request.getParameter("acte").equalsIgnoreCase("update")) { %>
        <h1>Modification d'un bon de commande fournisseur</h1>
    <% } else { %>
        <h1>Saisie d'un bon de commande fournisseur</h1>
    <% } %>

    <div class="box-body">
        <%-- ⚠ LE FORMULAIRE POSTE VERS apresMultiple.jsp (le moteur APJ) --%>
        <form class='container'
              action="<%=pi.getLien()%>?but=apresMultiple.jsp"
              method="post">

            <%-- Génère TOUT le HTML de l'en-tête (les champs de la mère) --%>
            <% out.println(pi.getFormu().getHtmlInsert()); %>

            <%-- Affichage du TOTAL (mis à jour par calculerMontantV2 en JS) --%>
            <div class="col-md-12 nopadding">
                <div class="col-md-12 cardradius">
                    <h3 class="fontinter" style="background: white; padding: 16px; margin-top: 10px; border-radius: 16px;">
                        Total : <span id="montanttotal">0</span><span id="deviseLibelle"> Ar</span>
                    </h3>
                </div>
            </div>

            <%-- Génère TOUT le HTML du tableau détail (les 10 lignes filles) --%>
            <% out.println(pi.getFormufle().getHtmlTableauInsert()); %>

            <%-- ═══════════════════════════════════════════════════════════
                 LES CHAMPS CACHÉS — LE CONTRAT AVEC apresMultiple.jsp
                 C'est CE QUE le moteur va lire pour savoir quoi faire.
                 ═══════════════════════════════════════════════════════════ --%>

            <%-- Champ "taxe" : rempli par l'autocomplétion fournisseur, surveillé par le JS --%>
            <input name="taxe" type="hidden" id="taxe" value="">

            <%-- L'ACTION à effectuer : insert (par défaut) --%>
            <input name="acte" type="hidden" id="nature" value="insert">

            <%-- OÙ rediriger après succès --%>
            <input name="bute" type="hidden" id="bute" value="<%= butApresPost %>">

            <%-- QUELLE classe Java instancier (réflexion) --%>
            <input name="classe" type="hidden" id="classe" value="<%= classeMere %>">
            <input name="classefille" type="hidden" id="classefille" value="<%= classeFille %>">

            <%-- Combien de lignes traiter + la colonne de liaison --%>
            <input name="nombreLigne" type="hidden" id="nombreLigne" value="<%= nombreLigne %>">
            <input name="colonneMere" type="hidden" id="colonneMere" value="<%= colonneMere %>">

            <%-- Dans quelle table écrire la fille --%>
            <input name="nomtable" type="hidden" id="nomtable" value="AS_BONDECOMMANDE_FILLE">
        </form>
    </div>
</div>
</div>

<%-- ═══════════════════════════════════════════════════════════
     SCRIPT 1 — MutationObserver sur "taxe"
     Surveille les changements d'attribut value du champ #taxe.
     Si taxe = '1.0' → remplit tous les tva_* avec la constante TVA.
     Sinon → met tous les tva_* à 0.
     ═══════════════════════════════════════════════════════════ --%>
<script>
    $(document).ready(function() {
        var nombreLigne = <%=nombreLigne%>;
        for (var i = 0; i < nombreLigne; i++) {
            calculerMontant(i);   // init du total au chargement
        }

        // Constante TVA injectée depuis Java (ConstanteCompta.constante_tva)
        const TAXE_VALUE = <%= ConstanteCompta.constante_tva %>;

        const taxeInput = document.getElementById('taxe');
        const tvaInputs = document.querySelectorAll('[id^="tva_"]');   // tous les tva_0, tva_1...

        // Observer les changements d'attribut "value" du champ #taxe
        const observer = new MutationObserver(() => {
            const newValue = taxeInput.value;
            if (newValue === '1.0') {
                tvaInputs.forEach(input => { input.value = TAXE_VALUE; });
            } else {
                tvaInputs.forEach(input => { input.value = '0'; });
            }
        });

        observer.observe(taxeInput, {
            attributes: true,
            attributeFilter: ['value']
        });
    });
</script>

<%-- ═══════════════════════════════════════════════════════════
     SCRIPT 2 — Calculs du total + recharge autocomplétion devise
     ═══════════════════════════════════════════════════════════ --%>
<script>

    // ─── calculerMontant : ancienne version simplifiée (pu × qte) ───
    function calculerMontant(indice, source) {
        var val = 0;
        $('input[id^="quantite_"]').each(function() {
            // Astuce : "quantite_3" → "pu_3" grâce au replace
            var quantite = parseFloat($("#" + $(this).attr('id').replace("quantite", "pu")).val());
            var montant  = parseFloat($(this).val());
            if (!isNaN(quantite) && !isNaN(montant)) {
                var value = quantite * montant;
                val += value;
            }
        });
        $("#montanttotal").html(val.toFixed(2));
    }

    // ─── calculerMontantV2 : LA vraie version complète ───
    // Pour chaque ligne : brut - remise ligne + TVA, puis remise globale en-tête
    function calculerMontantV2() {
        var listChamp = document.querySelectorAll('input[id^="pu_"]');
        let montantTtc = 0;

        for (let i = 0; i < listChamp.length; i++) {
            // ?.value || 0 : évite les NaN / null si le champ n'existe pas
            let pu     = parseFloat(document.getElementById("pu_" + i)?.value || 0);
            let qte    = parseFloat(document.getElementById("quantite_" + i)?.value || 0);
            let tva    = parseFloat(document.getElementById("tva_" + i)?.value || 0);
            let remise = parseFloat(document.getElementById("remise_" + i)?.value || 0);

            let montantremise = (pu * qte) * (remise / 100);
            montantTtc += ((pu * qte) - montantremise)
                        + (((pu * qte) - montantremise) * (tva / 100));
        }

        // Remise globale de l'en-tête (mère), appliquée APRÈS le calcul des lignes
        let remiseMere = parseFloat(document.getElementById("remise")?.value || 0);
        let montantRemiseMere = montantTtc * (remiseMere / 100);
        montantTtc -= montantRemiseMere;

        // Affichage formaté (12,345.67)
        document.getElementById("montanttotal").innerHTML = montantTtc.toLocaleString('en-US');
    }

    // Calcule le total au chargement du DOM
    document.addEventListener("DOMContentLoaded", function() {
        calculerMontantV2();
    });

    // ─── deviseModification : recharge l'autocomplétion produit selon la devise ───
    // Appelée quand on change idDevise dans l'en-tête.
    // Pour chaque ligne : détruit + recrée l'autocomplete produit
    // sur la vue ST_INGREDIENTSAUTOACHAT_AR/USD/EUR.
    function deviseModification() {

        var nombreLigne = parseInt($("#nombreLigne").val());

        for (let iL = 0; iL < nombreLigne; iL++) {
            $(function() {
                // Mapping devise → table SQL des produits
                var mapping = {
                    "AR":  { "table": "ST_INGREDIENTSAUTOACHAT_CPL" },
                    "USD": { "table": "ST_INGREDIENTSAUTOACHAT_USD" },
                    "EUR": { "table": "ST_INGREDIENTSAUTOACHAT_EUR" }
                };

                // Met à jour le libellé de devise affiché près du total
                $("#deviseLibelle").html($('#idDevise').val());

                var idDevise = $('#idDevise').val();
                // Recopie la devise dans la ligne iL (champ caché readonly)
                $("#idDevise_" + iL).val(idDevise);

                let autocompleteTriggered = false;  // garde-fou : ne cherche QUE si demandé

                // Nettoyage avant rebranchement (évite le cumul de handlers)
                $("#produit_" + iL + "libelle").autocomplete('destroy');
                $("#tauxDeChange_" + iL).val('');
                $("#pu_" + iL).val('');

                // Création du widget autocomplete
                $("#produit_" + iL + "libelle").autocomplete({
                    // source : appelée quand il faut chercher
                    source: function(request, response) {
                        $("#produit_" + iL).val('');   // invalide l'ID produit
                        if (autocompleteTriggered) {
                            fetchAutocomplete(
                                request, response,
                                "null", "id", "null",
                                mapping[idDevise].table,       // ⭐ table selon devise
                                "produits.IngredientsLib", "true",
                                "pu;taux;compte_achat;compte_achat;libelle"
                            );
                        }
                    },
                    // select : appelée quand l'utilisateur choisit un produit
                    select: function(event, ui) {
                        $("#produit_" + iL + "libelle").val(ui.item.label);
                        $("#produit_" + iL).val(ui.item.value);
                        $("#produit_" + iL).trigger('change');   // déclenche calculerMontantV2
                        $(this).autocomplete('disable');

                        // Remplit 5 champs en distribuant ui.item.retour
                        // ⚠ L'ordre doit matcher EXACTEMENT le mapping JSP
                        var champsDependant = [
                            'pu_' + iL, 'tauxDeChange_' + iL,
                            'compte_' + iL, 'comptelibelle_' + iL, 'produitLib_' + iL
                        ];
                        for (let i = 0; i < champsDependant.length; i++) {
                            $('#' + champsDependant[i]).val(ui.item.retour.split(';')[i]);
                        }
                        autocompleteTriggered = false;
                        return false;   // empêche le comportement par défaut
                    }
                }).autocomplete('disable');   // désactivée par défaut

                // Handler Tab : active + lance la recherche
                $("#produit_" + iL + "libelle").off('keydown');
                $("#produit_" + iL + "libelle").keydown(function(event) {
                    if (event.key === 'Tab') {
                        event.preventDefault();
                        autocompleteTriggered = true;
                        $(this).autocomplete('enable').autocomplete('search', $(this).val());
                    }
                });

                // Handler input : l'utilisateur tape → invalide + désactive
                $("#produit_" + iL + "libelle").off('input');
                $("#produit_" + iL + "libelle").on('input', function() {
                    $("#produit_" + iL).val('');
                    autocompleteTriggered = false;
                    $(this).autocomplete('disable');
                });

                // Handler clic sur la loupe : active + lance la recherche
                $("#produit_" + iL + "searchBtn").off('click');
                $("#produit_" + iL + "searchBtn").click(function() {
                    autocompleteTriggered = true;
                    $("#produit_" + iL + "libelle")
                        .autocomplete('enable')
                        .autocomplete('search', $("#produit_" + iL + "libelle").val());
                });
            });
        }
    }
</script>

<%-- ═══════════════════════════════════════════════════════════
     CATCH FINAL — pattern APJ standard
     Toute exception → alerte JS + retour arrière
     ═══════════════════════════════════════════════════════════ --%>
<%
    } catch (Exception e) {
        e.printStackTrace();
%>
<script language="JavaScript">
    alert('<%=e.getMessage()%>');
    history.back();
</script>
<% } %>