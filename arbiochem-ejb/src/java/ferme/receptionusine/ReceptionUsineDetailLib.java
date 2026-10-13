package ferme.receptionusine;

/**
 * Lecture de la vue RECEPTIONUSINEDETAIL_LIB : les pertes (MORT / PERDU)
 * d'une reception usine, avec le libelle de la qualite et le lot.
 *
 * @author 2026
 */
public class ReceptionUsineDetailLib extends ReceptionUsineDetail {

    private String idqualitepoussinlib, idlot;

    public ReceptionUsineDetailLib() throws Exception {
        super.setNomTable("RECEPTIONUSINEDETAIL_LIB");
    }

    public String getIdqualitepoussinlib() {
        return idqualitepoussinlib;
    }

    public void setIdqualitepoussinlib(String idqualitepoussinlib) {
        this.idqualitepoussinlib = idqualitepoussinlib;
    }

    public String getIdlot() {
        return idlot;
    }

    public void setIdlot(String idlot) {
        this.idlot = idlot;
    }
}
