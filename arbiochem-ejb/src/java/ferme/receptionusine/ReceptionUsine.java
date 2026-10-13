package ferme.receptionusine;

import bean.ClassMere;
import bean.ClassMAPTable;
import bean.CGenUtil;
import ferme.utils.ControlePoussin;
import java.sql.Connection;
import java.sql.Date;

/**
 * Reception des poussins a l'USINE, apres le transport depuis l'aeroport.
 *
 * On choisit le LOT, puis on saisit seulement les pertes du trajet
 * (MORT / PERDU). Les vivants sont calcules :
 *     qterecus (vivants) = vivants de la reception aeroport validee du lot
 *                          - morts - perdus
 *
 * Le sexe n'est pas connu a cette etape (il apparait a la repartition) :
 * idsexe et les cartons males / femelles restent vides / a 0.
 *
 * @author 2026
 */
public class ReceptionUsine extends ClassMere {

    private String id;
    private String idlot;
    private Date daty;
    private String heuredepart;
    private String heurearrive;
    private double qterecus;
    private int nbrcartonmale;
    private int nbrcartonfemelle;
    private String idvehicule;
    private String idchauffeur;
    private String idcontroleur;
    private String remarque;
    private int etat;

    public ReceptionUsine() throws Exception {
        super.setNomTable("RECEPTIONUSINE");
        this.setNomClasseFille("ferme.receptionusine.ReceptionUsineDetail");
        this.setLiaisonFille("idmere");
    }

    @Override
    public void construirePK(Connection c) throws Exception {
        this.preparePk("RUI", "GETSEQRECEPTIONUSINE");
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

    // ═══════════════════════════════════════════════════════════════
    //  CONTROLES
    // ═══════════════════════════════════════════════════════════════

    @Override
    public ClassMAPTable createObject(String u, Connection c) throws Exception {
        // « Modifier » repasse par ici : remplacer les lignes au lieu de les doubler
        ControlePoussin.preparerModification("RECEPTIONUSINE", "RECEPTIONUSINEDETAIL", "idmere", this.getId(), c);
        ReceptionUsineDetail[] fille = (ReceptionUsineDetail[]) this.getFille();
        controler(fille, c);
        return super.createObject(u, c);
    }

    /**
     * A la validation on rejoue les controles sur ce qui est en base
     * (la reception aeroport a pu changer entre la saisie et la validation).
     *
     * L'ecran n'envoie que l'id : on recharge d'abord la reception, car
     * ClassEtat.validerObject() reecrit tout l'enregistrement a partir de this.
     */
    @Override
    public Object validerObject(String u, Connection c) throws Exception {
        ReceptionUsine enBase = (ReceptionUsine) new ReceptionUsine()
                .getById(this.getId(), "RECEPTIONUSINE", c);
        if (enBase == null) {
            throw new Exception("La réception usine " + this.getId() + " n'existe pas.");
        }
        this.copierDepuis(enBase);

        ReceptionUsineDetail[] fille = (ReceptionUsineDetail[]) this.getFille(null, c, "");
        controler(fille, c);

        return super.validerObject(u, c);
    }

    /** Recopie les champs d'une reception lue en base. */
    private void copierDepuis(ReceptionUsine r) {
        this.setIdlot(r.getIdlot());
        this.setDaty(r.getDaty());
        this.setHeuredepart(r.getHeuredepart());
        this.setHeurearrive(r.getHeurearrive());
        this.setQterecus(r.getQterecus());
        this.setNbrcartonmale(r.getNbrcartonmale());
        this.setNbrcartonfemelle(r.getNbrcartonfemelle());
        this.setIdvehicule(r.getIdvehicule());
        this.setIdchauffeur(r.getIdchauffeur());
        this.setIdcontroleur(r.getIdcontroleur());
        this.setRemarque(r.getRemarque());
        this.setEtat(r.getEtat());
    }

    /**
     * Tous les controles de la reception usine, puis le calcul des vivants.
     *   1. le lot est obligatoire
     *   2. checkAntecedent : le lot a une reception aeroport validee
     *   3. le lot n'a pas deja une autre reception usine (hors annulees)
     *   4. chaque ligne est un MORT ou un PERDU avec qte > 0
     *   5. checkSomme : morts + perdus <= vivants de l'aeroport
     */
    public void controler(ReceptionUsineDetail[] fille, Connection c) throws Exception {
        if (this.getIdlot() == null || this.getIdlot().trim().isEmpty()) {
            throw new Exception("Le lot est obligatoire.");
        }
        double vivantsAeroport = ControlePoussin.checkReceptionAeroport(this.getIdlot(), c);
        checkLotDejaReceptionne(c);

        double pertes = 0;
        if (fille != null) {
            for (ReceptionUsineDetail f : fille) {
                ControlePoussin.checkLignePerte(f.getIdqualitepoussin(), f.getQte());
                f.setIdsexe(null);   // le sexe n'est connu qu'a la repartition
                pertes += f.getQte();
            }
        }
        ControlePoussin.checkSomme(vivantsAeroport, pertes,
                "les vivants de la réception aéroport du lot " + this.getIdlot());

        this.setQterecus(vivantsAeroport - pertes);
    }

    /** Un lot ne passe qu'une fois a l'usine (hors receptions annulees). */
    public void checkLotDejaReceptionne(Connection c) throws Exception {
        String sauf = (this.getId() != null) ? " and id <> '" + this.getId() + "'" : "";
        ReceptionUsine[] autres = (ReceptionUsine[]) CGenUtil.rechercher(
                new ReceptionUsine(), null, null, c,
                " and idlot = '" + this.getIdlot() + "' and etat > 0" + sauf);
        if (autres.length > 0) {
            throw new Exception("Le lot " + this.getIdlot()
                    + " a déjà une réception usine (" + autres[0].getId() + ").");
        }
    }

    // ═══════════════════════════════════════════════════════════════
    //  GETTERS / SETTERS
    // ═══════════════════════════════════════════════════════════════

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getIdlot() {
        return idlot;
    }

    public void setIdlot(String idlot) {
        this.idlot = idlot;
    }

    public Date getDaty() {
        return daty;
    }

    public void setDaty(Date daty) {
        this.daty = daty;
    }

    public String getHeuredepart() {
        return heuredepart;
    }

    public void setHeuredepart(String heuredepart) {
        this.heuredepart = heuredepart;
    }

    public String getHeurearrive() {
        return heurearrive;
    }

    public void setHeurearrive(String heurearrive) {
        this.heurearrive = heurearrive;
    }

    public double getQterecus() {
        return qterecus;
    }

    public void setQterecus(double qterecus) {
        this.qterecus = qterecus;
    }

    public int getNbrcartonmale() {
        return nbrcartonmale;
    }

    public void setNbrcartonmale(int nbrcartonmale) {
        this.nbrcartonmale = nbrcartonmale;
    }

    public int getNbrcartonfemelle() {
        return nbrcartonfemelle;
    }

    public void setNbrcartonfemelle(int nbrcartonfemelle) {
        this.nbrcartonfemelle = nbrcartonfemelle;
    }

    public String getIdvehicule() {
        return idvehicule;
    }

    public void setIdvehicule(String idvehicule) {
        this.idvehicule = idvehicule;
    }

    public String getIdchauffeur() {
        return idchauffeur;
    }

    public void setIdchauffeur(String idchauffeur) {
        this.idchauffeur = idchauffeur;
    }

    public String getIdcontroleur() {
        return idcontroleur;
    }

    public void setIdcontroleur(String idcontroleur) {
        this.idcontroleur = idcontroleur;
    }

    public String getRemarque() {
        return remarque;
    }

    public void setRemarque(String remarque) {
        this.remarque = remarque;
    }

    public int getEtat() {
        return etat;
    }

    public void setEtat(int etat) {
        this.etat = etat;
    }
}