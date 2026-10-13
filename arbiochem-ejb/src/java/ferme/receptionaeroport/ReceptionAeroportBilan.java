package ferme.receptionaeroport;

import bean.ClassMAPTable;
import java.sql.Date;

/**
 * Lecture de la vue v_reception_aeroport_bilan :
 * commande / morts / perdus / vivants d'une reception aeroport.
 *   nbvivant = qtecommande - nbmort - nbperdu
 * (sql/01_schema_elevage.sql, section 5.2)
 */
public class ReceptionAeroportBilan extends ClassMAPTable {
    private String id;
    private String idlot;
    private String idbc;
    private Date daty;
    private int etat;
    private double qtecommande;
    private double nbmort;
    private double nbperdu;
    private double nbvivant;

    public ReceptionAeroportBilan() {
        this.setNomTable("v_reception_aeroport_bilan");
    }

    @Override
    public String getTuppleID() {
        return id;
    }

    @Override
    public String getAttributIDName() {
        return "id";
    }

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

    public String getIdbc() {
        return idbc;
    }

    public void setIdbc(String idbc) {
        this.idbc = idbc;
    }

    public Date getDaty() {
        return daty;
    }

    public void setDaty(Date daty) {
        this.daty = daty;
    }

    public int getEtat() {
        return etat;
    }

    public void setEtat(int etat) {
        this.etat = etat;
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
