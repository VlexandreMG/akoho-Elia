package ferme.receptionaeroport;
import java.sql.Connection;

/**
 * Lecture de la vue RECEPTIONPOUSSINAEROPORT_LIB (liste + fiche).
 * qtecommande / nbmort / nbperdu / nbvivant viennent de v_reception_aeroport_bilan.
 *
 * @author Safidy
 */
public class ReceptionPoussinAeroportLib extends ReceptionPoussinAeroport {
    private String idLotLib,etatLib,idbcLib;
    private int nbrCartonTotal;
    private double qtecommande, nbmort, nbperdu, nbvivant;
    public ReceptionPoussinAeroportLib()throws Exception{
        super.setNomTable("receptionPoussinAeroport_lib");
    }

    public int getNbrCartonTotal() {
        return nbrCartonTotal;
    }

    public void setNbrCartonTotal(int nbrCartonTotal) {
        this.nbrCartonTotal = nbrCartonTotal;
    }

    public String getEtatLib() {
        return etatLib;
    }

    public void setEtatLib(String etatLib) {
        this.etatLib = etatLib;
    }

    public String getIdLotLib() {
        return idLotLib;
    }

    public void setIdLotLib(String idLotLib) {
        this.idLotLib = idLotLib;
    }

    public String getIdbcLib() {
        return idbcLib;
    }

    public void setIdbcLib(String idbcLib) {
        this.idbcLib = idbcLib;
    }

    public double getQtecommande() {
        return qtecommande;
    }

    public void setQtecommande(double qtecommande) {
        this.qtecommande = qtecommande;
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
