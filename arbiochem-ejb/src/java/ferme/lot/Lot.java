package ferme.lot;

import bean.ClassEtat;
import java.sql.Connection;
import java.sql.Date;
import bean.CGenUtil;
import bean.ClassMAPTable;

public class Lot extends ClassEtat {
    private String id;
    private String nomlot;
    private String reference;
    private Date dateeclosion;
    private Date datearrivee,dateCloture;
    private String source;
    private String idferme;
    private String idarticle;
    private String idorigine;
    private String idprogramme,idSouche,idCategorieLot;

    /**
     * Bon de commande fournisseur source (AS_BONDECOMMANDE.id).
     * Ajoute le 04/10/2026 - liaison etape 1 du flux elevage.
     * Remplace le lien direct BC -> reception : on passe par le LOT.
     */
    private String idbc;

    /**
     * Nombre de morts saisi à la création (ou modification) du lot.
     * Sprint 2 (17/10/2026) : colonne LOT.NOMBREMORT NUMBER DEFAULT 0.
     * Sert à la prévision poussins : effectif réel = disponibles - ces morts.
     * type int => le framework APJ affiche/convertit en entier ;
     * champ vide dans le formulaire => 0 (Utilitaire.stringToInt renvoie 0).
     * ⚠ La colonne doit valoir UPPERCASE(nom du champ) sinon le framework
     * ne fait pas le lien champ<->colonne (d'où NBMORT -> NOMBREMORT).
     */
    private int nombremort; // valeur stockée dans la colonne LOT.NOMBREMORT

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getNomlot() {
        return nomlot;
    }

    public void setNomlot(String nomlot) {
        this.nomlot = nomlot;
    }

    public String getReference() {
        return reference;
    }

    public void setReference(String reference) {
        this.reference = reference;
    }

    public Date getDateeclosion() {
        return dateeclosion;
    }

    public void setDateeclosion(Date dateeclosion) {
        this.dateeclosion = dateeclosion;
    }

    public Date getDatearrivee() {
        return datearrivee;
    }

    public void setDatearrivee(Date datearrivee) {
        this.datearrivee = datearrivee;
    }

    public String getSource() {
        return source;
    }

    public void setSource(String source) {
        this.source = source;
    }

    public String getIdferme() {
        return idferme;
    }

    public void setIdferme(String idferme) {
        this.idferme = idferme;
    }

    public String getIdarticle() {
        return idarticle;
    }

    public void setIdarticle(String idarticle) {
        this.idarticle = idarticle;
    }

    public String getIdorigine() {
        return idorigine;
    }

    public void setIdorigine(String idorigine) {
        this.idorigine = idorigine;
    }

    public String getIdprogramme() {
        return idprogramme;
    }

    public void setIdprogramme(String idprogramme) {
        this.idprogramme = idprogramme;
    }
    @Override
    public ClassMAPTable createObject(String u,Connection c)throws Exception
    {
        checkDates();
        checkNomLotEtReference(c);
        ClassMAPTable o=super.createObject(u,c);
        return o;
    }
    public Date getDateCloture() {
        return dateCloture;
    }

    public void setDateCloture(Date dateCloture) {
        this.dateCloture = dateCloture;
    }

    public String getIdCategorieLot() {
        return idCategorieLot;
    }

    public void setIdCategorieLot(String idCategorieLot) {
        this.idCategorieLot = idCategorieLot;
    }

    public String getIdbc() {
        return idbc;
    }

    /**
     * Lecteur du nombre de morts (appelé par le framework APJ en réflexion) :
     * - PageInsert : alimente la valeur affichée dans le champ du formulaire ;
     * - CGenUtil.getValeurInsert : construit la valeur de la colonne NBMORT ;
     * - CGenUtil.rechercher : remplit ce champ depuis le SELECT sur LOT.
     * @return nombre de morts du lot (0 si jamais saisi/vide en base)
     */
    public int getNombremort() {
        // ligne 1 : renvoie l'attribut de l'objet (valeur courante)
        return nombremort;
    }

    /**
     * Écriture du nombre de morts (appelé aussi en réflexion par le framework) :
     * - getObjectAvecValeur (apresTarif.jsp) : convertit le texte tapé en int
     *   ("" ou non numérique => 0 via Utilitaire.stringToInt) puis appelle ce setter ;
     * - CGenUtil.rechercher : écrit la colonne NBMORT lue en base dans l'objet.
     * @param nombremort nombre de morts à enregistrer pour ce lot
     */
    public void setNombremort(int nombremort) {
        // ligne 1 : stocke la valeur dans l'attribut (mappé colonne LOT.NBMORT)
        this.nombremort = nombremort;
    }

    public void setIdbc(String idbc) {
        this.idbc = idbc;
    }

    public Lot() throws Exception {
        this.setNomTable("LOT");
    }

    @Override
    public void construirePK(Connection c) throws Exception {
        this.preparePk("LOT","getseq_lot");
        this.setId(makePK(c));
    }

    @Override
    public String getTuppleID() {
        return id;
    }

    @Override
    public String getAttributIDName() {
        return "id";
    }

    @Override
    public String[] getMotCles() {
        String[] motCles={"nomlot"};
        return motCles;
    }

    @Override
    public String[] getValMotCles() {
        String[] valMotCles={"nomlot"};
        return valMotCles;
    }

    public String getIdSouche() {
        return idSouche;
    }

    public void setIdSouche(String idSouche) {
        this.idSouche = idSouche;
    }

    public void checkNomLotEtReference(Connection c)throws Exception{
        if(this.getNomlot()==null || this.getNomlot().equals("") || this.getReference()==null || this.getReference().equals("")){
            throw new Exception("Le nom du lot et la r\u00E9f\u00E9rence ne peuvent pas \u00EAtre vides");
        }
        else{
            Lot[] lots = (Lot[]) CGenUtil.rechercher(new Lot(), null,null,c," and (UPPER(nomLot) = UPPER('"+this.getNomlot()+"')) OR UPPER(reference) = UPPER('"+this.getReference()+"')");
            if(lots.length>0){
                throw new Exception("Le m\u00EAme nom du lot et/ou la r\u00E9f\u00E9rence existent d\u00E9j\u00E0");
            }
        }
    }

    public void checkDates() throws Exception {
        if (this.getDateeclosion() == null) {
            throw new Exception("La date d'éclosion est obligatoire");
        }
        if (this.getDatearrivee() == null) {
            throw new Exception("La date d'arrivée est obligatoire");
        }
        if (this.getDateeclosion().after(this.getDatearrivee())) {
            throw new Exception("La date d'éclosion ne peut pas être supérieure à la date d'arrivée");
        }
    }
}

