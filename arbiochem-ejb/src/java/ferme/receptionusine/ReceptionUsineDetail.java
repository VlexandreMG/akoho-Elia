package ferme.receptionusine;

import bean.ClassFille;
import java.sql.Connection;

/**
 * Ligne de triage de la reception usine : sexe + qualite + quantite.
 * Controle unitaire : la quantite doit etre strictement positive.
 *
 * @author 2026
 */
public class ReceptionUsineDetail extends ClassFille {

    private String id;
    private String idmere;
    private String idsexe;
    private String idqualitepoussin;
    private double qte;

    public ReceptionUsineDetail() throws Exception {
        super.setNomTable("RECEPTIONUSINEDETAIL");
        this.setNomClasseMere("ferme.receptionusine.ReceptionUsine");
        this.setLiaisonMere("idmere");
    }

    @Override
    public void construirePK(Connection c) throws Exception {
        this.preparePk("RUIF", "GETSEQRECEPTIONUSINEDETAIL");
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
    public String getNomClasseMere() {
        return "ferme.receptionusine.ReceptionUsine";
    }

    @Override
    public String getLiaisonMere() {
        return "idmere";
    }

    // ═══ CONTROLE UNITAIRE ═══
    public void setQte(double qte) throws Exception {
        if (qte <= 0) {
            throw new Exception("La quantite doit etre superieure a 0.");
        }
        this.qte = qte;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getIdmere() {
        return idmere;
    }

    public void setIdmere(String idmere) {
        this.idmere = idmere;
    }

    public String getIdsexe() {
        return idsexe;
    }

    public void setIdsexe(String idsexe) {
        this.idsexe = idsexe;
    }

    public String getIdqualitepoussin() {
        return idqualitepoussin;
    }

    public void setIdqualitepoussin(String idqualitepoussin) {
        this.idqualitepoussin = idqualitepoussin;
    }

    public double getQte() {
        return qte;
    }
}