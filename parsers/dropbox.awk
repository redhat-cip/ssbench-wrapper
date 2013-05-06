BEGIN { total="false"; create="false"; read="false"; update="false"; del="false" }
/^TOTAL/    { total="true"; create="false"; read="false"; update="false"; del="false";}
/^READ/    { total="false"; create="false"; read="true"; update="false"; del="false";}
/^CREATE/    { total="false"; create="true"; read="false"; update="false"; del="false";}
/^UPDATE/    { total="false"; create="false"; read="false"; update="true"; del="false";}
/^DELETE/    { total="false"; create="false"; read="false"; update="false"; del="true";}
/Count/    { if (total=="true") opt=$NF;
             else if (read=="true") opr=$NF;
             else if (create=="true") opc=$NF;
             else if (update=="true") opu=$NF;
             else if (del=="true") opd=$NF;
           }
/Last-byte/ && /Medium files objs/ {
             if (total=="true") tmfo=$6;
             else if (read=="true") rmfo=$6;
             else if (create=="true") cmfo=$6;
             else if (update=="true") umfo=$6;
             else if (del=="true") dmfo=$6;
}
/Last-byte/ && /Large files objs/ {
             if (total=="true") tlfo=$6;
             else if (read=="true") rlfo=$6;
             else if (create=="true") clfo=$6;
             else if (update=="true") ulfo=$6;
             else if (del=="true") dlfo=$6;
}
/Last-byte/ && /Very large files objs/ {
             if (total=="true") tvlfo=$6;
             else if (read=="true") rvlfo=$6;
             else if (create=="true") cvlfo=$6;
             else if (update=="true") uvlfo=$6;
             else if (del=="true") dvlfo=$6;
}
END { print "Compute results in CSV file";
      header="total"
      if (opc>0) header = header",create";
      if (opr>0) header = header",read";
      if (opu>0) header = header",update";
      if (opd>0) header = header",delete";
      print header > ENVIRON["WORKSPACE"]"/dropbox-ops.csv";
      print opt","opc","opr","opu","opd >> ENVIRON["WORKSPACE"]"/dropbox-ops.csv";
      print "Medium object,Large Object,Very large object" > ENVIRON["WORKSPACE"]"/dropbox-total-ops-details.csv"
      print tmfo","tlfo","tvlfo >> ENVIRON["WORKSPACE"]"/dropbox-total-ops-details.csv"
      print "Medium object,Large Object,Very large object" > ENVIRON["WORKSPACE"]"/dropbox-read-ops-details.csv"
      print rmfo","rlfo","rvlfo >> ENVIRON["WORKSPACE"]"/dropbox-read-ops-details.csv"
      print "Medium object,Large Object,Very large object" > ENVIRON["WORKSPACE"]"/dropbox-create-ops-details.csv"
      print cmfo","clfo","cvlfo >> ENVIRON["WORKSPACE"]"/dropbox-create-ops-details.csv"
      print "Medium object,Large Object,Very large object" > ENVIRON["WORKSPACE"]"/dropbox-update-ops-details.csv"
      print umfo","ulfo","uvlfo >> ENVIRON["WORKSPACE"]"/dropbox-update-ops-details.csv"
      print "Medium object,Large Object,Very large object" > ENVIRON["WORKSPACE"]"/dropbox-delete-ops-details.csv"
      print dmfo","dlfo","dvlfo >> ENVIRON["WORKSPACE"]"/dropbox-delete-ops-details.csv"
    }
