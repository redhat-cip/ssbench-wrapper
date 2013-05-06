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
/Last-byte/ && /Ultra small file/ {
             if (total=="true") tusf=$6;
             else if (read=="true") rusf=$6;
             else if (create=="true") cusf=$6;
             else if (update=="true") uusf=$6;
             else if (del=="true") dusf=$6;
}
/Last-byte/ && /Small files objs/ {
             if (total=="true") tsfo=$6;
             else if (read=="true") rsfo=$6;
             else if (create=="true") csfo=$6;
             else if (update=="true") usfo=$6;
             else if (del=="true") dsfo=$6;
}
/Last-byte/ && /Medium files objs/ {
             if (total=="true") tmfo=$6;
             else if (read=="true") rmfo=$6;
             else if (create=="true") cmfo=$6;
             else if (update=="true") umfo=$6;
             else if (del=="true") dmfo=$6;
}
END { print "Compute results in CSV file";
      header="total"
      if (opc>0) header = header",create";
      if (opr>0) header = header",read";
      if (opu>0) header = header",update";
      if (opd>0) header = header",delete";
      print header > ENVIRON["WORKSPACE"]"/webserver-ops.csv";
      print opt","opr >> ENVIRON["WORKSPACE"]"/webserver-ops.csv";
      print "Ultra small objects,Small object,Medium Object" > ENVIRON["WORKSPACE"]"/webserver-total-ops-details.csv"
      print tusf","tsfo","tmfo >> ENVIRON["WORKSPACE"]"/webserver-total-ops-details.csv"
      print "Ultra small objects,Small object,Medium Object" > ENVIRON["WORKSPACE"]"/webserver-read-ops-details.csv"
      print rusf","rsfo","rmfo >> ENVIRON["WORKSPACE"]"/webserver-read-ops-details.csv"
    }
