ojdbc8-full.tar.gz - JDBC Thin Driver and Companion JARS
========================================================
This TAR archive (ojdbc8-full.tar.gz) contains the 18.3 release of the Oracle JDBC Thin driver(ojdbc8.jar), the Universal Connection Pool (ucp.jar) and other companion JARs grouped by category. 

(1) ojdbc8.jar (4,161,744 bytes) - 
(SHA1 Checksum: 4acaa9ab2b7470fa80f0a8ec416d7ea86608ac8c)
Certified with JDK 8; 

(2) ucp.jar (1,398,331 bytes) - (SHA1 Checksum:b844d15da29d5c4f23a230318f9fd808087a9962)
Universal Connection Pool classes for use with JDK 8 -- for performance, scalability, high availability, sharded and multitenant databases.

(3) ojdbc.policy (11,596 bytes) - Sample security policy file for Oracle Database JDBC drivers

======================
Security Related JARs
======================
Java applications require some additional jars to use Oracle Wallets. 
You need to use all the three jars while using Oracle Wallets. 

(4) oraclepki.jar (307,817 bytes) - (SHA1 Checksum: 347500d8238a67e8b10b55a2d986b9c92ba495b3)
Additional jar required to access Oracle Wallets from Java
(5) osdt_cert.jar (205,152 bytes) - (SHA1 Checksum: 50c0e74c61e169adff5b83cb6a4fe1d7f4b53e8e)
Additional jar required to access Oracle Wallets from Java
(6) osdt_core.jar (306,854 bytes) - (SHA1 Checksum: 1e057b50515c973e3f4f0323473806b7c737771e)
Additional jar required to access Oracle Wallets from Java

=============================
JARs for NLS and XDK support 
=============================
(7) orai18n.jar (1,661,545 bytes) - (SHA1 Checksum: 47e509c469052c512fee478df59637f448973156) 
Classes for NLS support
(8) xdb6.jar (262,415 bytes) - (SHA1 Checksum: 4fdcbc031a2347234d60bc123134aec4b5bad76d)
Classes to support standard JDBC 4.x java.sql.SQLXML interface 

====================================================
JARs for Real Application Clusters(RAC), ADG, or DG 
====================================================
(9) ons.jar (144,428 bytes) - (SHA1 Checksum: 54775efa851d4f27bfd5019572ab22b83c4f21d4)
for use by the pure Java client-side Oracle Notification Services (ONS) daemon
(10) simplefan.jar (29,103 bytes) - (SHA1 Checksum: 8559b89d1a504aee09f51ca07b668d85c371531a)
Java APIs for subscribing to RAC events via ONS; simplefan policy and javadoc

=================
USAGE GUIDELINES
=================
Refer to the JDBC Developers Guide (https://docs.oracle.com/en/database/oracle/oracle-database/18/jjdbc/index.html) and Universal Connection Pool Developers Guide (https://docs.oracle.com/en/database/oracle/oracle-database/18/jjucp/index.html)for more details. 
