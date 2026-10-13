package ferme.receptionusine;

/**
 * Lecture de la vue RECEPTIONUSINE_LIB (liste + fiche).
 * qteattendue / nbmort / nbperdu / nbvivant viennent de v_reception_usine_bilan :
 *   qteattendue = vivants de la reception aeroport validee du lot
 *   nbvivant    = qteattendue - nbmort - nbperdu
 * (sql/01_schema_elevage.sql, sections 5.3 et 5.11)
 *
 * @author 2026
 */
public class ReceptionUsineLib extends ReceptionUsine {

    private String idlotlib, etatlib;
    private double qteattendue, nbmort, nbperdu, nbvivant;

    public ReceptionUsineLib() throws Exception {
        super.setNomTable("RECEPTIONUSINE_LIB");
    }

    public String getIdlotlib() {
        return idlotlib;
    }

    public void setIdlotlib(String idlotlib) {
        this.idlotlib = idlotlib;
    }

    public String getEtatlib() {
        return etatlib;
    }

    public void setEtatlib(String etatlib) {
        this.etatlib = etatlib;
    }

    public double getQteattendue() {
        return qteattendue;
    }

    public void setQteattendue(double qteattendue) {
        this.qteattendue = qteattendue;
    }

    public double getNbmort() {
        return nbmort;
    }

    public void setNbmort(double nbmort) {
        this.nbmort = nbmort;
    }

    public double getNbperdu() {
        return nbperdu;
    }

    public void setNbperdu(double nbperdu) {
        this.nbperdu = nbperdu;
    }

    public double getNbvivant() {
        return nbvivant;
    }

    public void setNbvivant(double nbvivant) {
        this.nbvivant = nbvivant;
    }
}
