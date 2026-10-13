package ferme.receptionaeroport;

import java.sql.Connection;
import bean.CGenUtil;
import bean.ClassMere;
import java.sql.Date;
import bean.ClassMAPTable;
import ferme.lot.Lot;
import ferme.utils.ControlePoussin;
/**
 * Reception des poussins a l'aeroport.
 *
 * On choisit le BON DE COMMANDE des poussins, puis on saisit seulement
 * les pertes (MORT / PERDU). Les vivants sont calcules :
 *     qteRecus (vivants) = quantite commandee - morts - perdus
 *
 * Le sexe n'est pas connu a cette etape (il apparait a la repartition).
 *
 * @author Safidy
 */
public class ReceptionPoussinAeroport extends ClassMere {
    private String id,idLot,remarque, heureDepart, heureArrive;
    private String idbc;
    private Date daty;
    private double qteRecus;
    private int nbrCartonMale,nbrCartonFemelle,etat;
    public ReceptionPoussinAeroport()throws Exception {
        super.setNomTable("receptionPoussinAeroport");
        this.setNomClasseFille("ferme.receptionaeroport.ReceptionPoussinAeroportDetail");
        this.setLiaisonFille("idMere");
    }

    @Override
    public void construirePK(Connection c) throws Exception {
        this.preparePk("RPA", "GETSEQRECEPTIONPOUSSINAEROPORT");
        this.setId(this.makePK(c));
    }
    @Override
    public String getTuppleID() {
        return id;
    }

    public int getNbrCartonMale() {
        return nbrCartonMale;
    }

    public int getEtat() {
        return etat;
    }

    public void setEtat(int etat) {
        this.etat = etat;
    }

    public void setNbrCartonMale(int nbrCartonMale) {
        this.nbrCartonMale = nbrCartonMale;
    }

    public int getNbrCartonFemelle() {
        return nbrCartonFemelle;
    }

    public void setNbrCartonFemelle(int nbrCartonFemelle) {
        this.nbrCartonFemelle = nbrCartonFemelle;
    }

    @Override
    public String getAttributIDName() {
        return "id";
    }

    @Override
    public String getNomClasseFille() {
        return "ferme.receptionaeroport.ReceptionPoussinAeroportDetail";
    }

    @Override
    public String getLiaisonFille() {
        return "idMere";
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getIdLot() {
        return idLot;
    }

    public void setIdLot(String idLot) {
        this.idLot = idLot;
    }

    public String getIdbc() {
        return idbc;
    }

    public void setIdbc(String idbc) {
        this.idbc = idbc;
    }

    public String getRemarque() {
        return remarque;
    }

    public void setRemarque(String remarque) {
        this.remarque = remarque;
    }

    public Date getDaty() {
        return daty;
    }

    public void setDaty(Date daty) {
        this.daty = daty;
    }

    public double getQteRecus() {
        return qteRecus;
    }

    public void setQteRecus(double qteRecus) {
        this.qteRecus = qteRecus;
    }

    public String getHeureDepart() {
        return heureDepart;
    }

    public void setHeureDepart(String heureDepart) {
        this.heureDepart = heureDepart;
    }

    public String getHeureArrive() {
        return heureArrive;
    }

    public void setHeureArrive(String heureArrive) {
        this.heureArrive = heureArrive;
    }

    // ═══════════════════════════════════════════════════════════════
    //  CONTROLES
    // ═══════════════════════════════════════════════════════════════
    //creer objet avec controle 
    @Override
    public ClassMAPTable createObject(String u, Connection c) throws Exception {
        // « Modifier » repasse par ici : remplacer les lignes au lieu de les doubler
        ControlePoussin.preparerModification("RECEPTIONPOUSSINAEROPORT", "RECEPTIONPOUSSINAEROPORTDETAIL", "idmere", this.getId(), c);
        ReceptionPoussinAeroportDetail[] fille = (ReceptionPoussinAeroportDetail[]) this.getFille();
        controler(fille, c);
        return super.createObject(u, c);
    }

    /**
     * A la validation on rejoue les controles sur ce qui est en base
     * (le BC a pu changer entre la saisie et la validation),
     * puis on rattache le bon de commande au lot.
     *
     * L'ecran n'envoie que l'id : on recharge d'abord la reception, car
     * ClassEtat.validerObject() reecrit tout l'enregistrement a partir de this.
     */
    //valider object : enregistrement dans base 
    @Override
    public Object validerObject(String u, Connection c) throws Exception {
        ReceptionPoussinAeroport enBase = (ReceptionPoussinAeroport) new ReceptionPoussinAeroport()
                .getById(this.getId(), "receptionPoussinAeroport", c);
        if (enBase == null) {
            throw new Exception("La réception " + this.getId() + " n'existe pas.");
        }
        this.copierDepuis(enBase);

        ReceptionPoussinAeroportDetail[] fille =
                (ReceptionPoussinAeroportDetail[]) this.getFille(null, c, "");
        controler(fille, c);

        Object o = super.validerObject(u, c);
        lierBcAuLot(c);
        return o;
    }

    /** Recopie les champs d'une reception lue en base. */
    private void copierDepuis(ReceptionPoussinAeroport r) {
        this.setIdLot(r.getIdLot());
        this.setIdbc(r.getIdbc());
        this.setDaty(r.getDaty());
        this.setQteRecus(r.getQteRecus());
        this.setRemarque(r.getRemarque());
        this.setHeureDepart(r.getHeureDepart());
        this.setHeureArrive(r.getHeureArrive());
        this.setNbrCartonMale(r.getNbrCartonMale());
        this.setNbrCartonFemelle(r.getNbrCartonFemelle());
        this.setEtat(r.getEtat());
    }

    /**
     * Tous les controles de la reception aeroport, puis le calcul des vivants.
     *   1. le lot est obligatoire
     *   2. le BC existe, est valide et contient des poussins
     *   3. le BC n'est pas deja utilise par une autre reception aeroport
     *   4. chaque ligne est un MORT ou un PERDU avec qte > 0
     *   5. checkSomme : morts + perdus <= quantite commandee
     */
    public void controler(ReceptionPoussinAeroportDetail[] fille, Connection c) throws Exception {
        if (this.getIdLot() == null || this.getIdLot().trim().isEmpty()) {
            throw new Exception("Le lot est obligatoire.");
        }
        double qteCommande = ControlePoussin.checkBcPoussin(this.getIdbc(), c);
        checkBcDejaUtilise(c);

        double pertes = 0;
        if (fille != null) {
            for (ReceptionPoussinAeroportDetail f : fille) {
                ControlePoussin.checkLignePerte(f.getIdQualitePoussin(), f.getQte());
                f.setIdSexe(null);   // le sexe n'est connu qu'a la repartition
                pertes += f.getQte();
            }
        }
        ControlePoussin.checkSomme(qteCommande, pertes,
                "la quantité commandée sur " + this.getIdbc());

        this.setQteRecus(qteCommande - pertes);
    }

    /** Un bon de commande ne sert qu'a une seule reception aeroport (hors annulees). */
    public void checkBcDejaUtilise(Connection c) throws Exception {
        String sauf = (this.getId() != null) ? " and id <> '" + this.getId() + "'" : "";
        ReceptionPoussinAeroport[] autres = (ReceptionPoussinAeroport[]) CGenUtil.rechercher(
                new ReceptionPoussinAeroport(), null, null, c,
                " and idbc = '" + this.getIdbc() + "' and etat > 0" + sauf);
        if (autres.length > 0) {
            throw new Exception("Le bon de commande " + this.getIdbc()
                    + " est déjà utilisé par la réception " + autres[0].getId() + ".");
        }
    }

    /**
     * Recopie le bon de commande sur le lot (LOT.idbc).
     * Refuse si le lot est deja rattache a un AUTRE bon de commande.
     */
    public void lierBcAuLot(Connection c) throws Exception {
        Lot lot = (Lot) new Lot().getById(this.getIdLot(), "LOT", c);
        if (lot == null) {
            throw new Exception("Le lot " + this.getIdLot() + " n'existe pas.");
        }
        if (lot.getIdbc() != null && !lot.getIdbc().isEmpty()
                && !lot.getIdbc().equals(this.getIdbc())) {
            throw new Exception("Le lot " + lot.getNomlot() + " est déjà rattaché au bon de commande "
                    + lot.getIdbc() + ".");
        }
        lot.setIdbc(this.getIdbc());
        lot.updateToTable(c);
    }
}
