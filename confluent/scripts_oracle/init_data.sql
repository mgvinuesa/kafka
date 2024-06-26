-- https://www.oracle.com/application-development/technologies/eclipse/salesdb-sql.html

CREATE TABLE C##MYUSER.PRODUCT(PRODUCTID INTEGER NOT NULL PRIMARY KEY,CODE VARCHAR(5),NAME VARCHAR(100),UNITPRICE NUMERIC(6,2) NOT NULL) tablespace USERS;
CREATE TABLE C##MYUSER.CUSTOMERID(CUSTOMERID INTEGER NOT NULL PRIMARY KEY,DRV_LIC_NO INTEGER NOT NULL,CONSTRAINT UNI_LIC_NO UNIQUE(DRV_LIC_NO)) tablespace USERS;
CREATE TABLE C##MYUSER.CUSTOMER(CUSTOMERID INTEGER NOT NULL PRIMARY KEY,NAME VARCHAR(255) NOT NULL) tablespace USERS;
CREATE TABLE C##MYUSER.ORDER_DATA(ORDERID INTEGER NOT NULL PRIMARY KEY,ORDERDATE VARCHAR(12),CUSTOMERID INTEGER,AMOUNT NUMERIC(6,2) NOT NULL,CONSTRAINT CUSTID FOREIGN KEY(CUSTOMERID) REFERENCES C##MYUSER.CUSTOMER(CUSTOMERID))tablespace USERS;

CREATE TABLE C##MYUSER.LINEITEM(ORDERLINE INTEGER NOT NULL PRIMARY KEY,ORDERID INTEGER NOT NULL,PRODUCTID INTEGER NOT NULL,QUANTITY NUMERIC(4) NOT NULL,
CONSTRAINT PRODID FOREIGN KEY(PRODUCTID) REFERENCES C##MYUSER.PRODUCT(PRODUCTID),CONSTRAINT ORDID FOREIGN KEY(ORDERID) REFERENCES 
C##MYUSER.ORDER_DATA(ORDERID)) tablespace USERS;

CREATE TABLE C##MYUSER.CONTACT(CONTACTID VARCHAR(30) NOT NULL PRIMARY KEY,CUSTOMERID INTEGER NOT NULL,ADDRESS VARCHAR(150),CITY VARCHAR(50),
PHONE VARCHAR(20),CONSTRAINT CONTACT_CUSTID FOREIGN KEY(CUSTOMERID) REFERENCES C##MYUSER.CUSTOMER(CUSTOMERID)) tablespace USERS;

INSERT INTO C##MYUSER.PRODUCT VALUES(10,'AB123','Leather Sofa',1000);
INSERT INTO C##MYUSER.PRODUCT VALUES(20,'AB456','Baby Chair',200.25);
INSERT INTO C##MYUSER.PRODUCT VALUES(30,'AB789','Sport Shoes',250.60);
INSERT INTO C##MYUSER.PRODUCT VALUES(40,'PQ123','Sony Digital Camera',399);
INSERT INTO C##MYUSER.PRODUCT VALUES(50,'PQ456','Hitachi HandyCam',1050);
INSERT INTO C##MYUSER.PRODUCT VALUES(60,'PQ789','GM Saturn',2250.99);
INSERT INTO C##MYUSER.CUSTOMERID VALUES(101,10101010);
INSERT INTO C##MYUSER.CUSTOMERID VALUES(102,20202020);
INSERT INTO C##MYUSER.CUSTOMER VALUES(101,'RICKY');
INSERT INTO C##MYUSER.CUSTOMER VALUES(102,'JOHN');
INSERT INTO C##MYUSER.CUSTOMER VALUES(103,'TONY');
INSERT INTO C##MYUSER.CUSTOMER VALUES(104,'Bob');
INSERT INTO C##MYUSER.CUSTOMER VALUES(105,'Willium');
INSERT INTO C##MYUSER.CUSTOMER VALUES(106,'Mihir');
INSERT INTO C##MYUSER.CUSTOMER VALUES(107,'Kevin');
INSERT INTO C##MYUSER.CUSTOMER VALUES(108,'Sam');
INSERT INTO C##MYUSER.ORDER_DATA VALUES(51,'2/3/2005',101,3250.25);
INSERT INTO C##MYUSER.ORDER_DATA VALUES(52,'3/4/2005',101,2751.2);
INSERT INTO C##MYUSER.ORDER_DATA VALUES(53,'4/5/2005',101,2250.99);
INSERT INTO C##MYUSER.ORDER_DATA VALUES(54,'3/3/2005',101,2499);
INSERT INTO C##MYUSER.ORDER_DATA VALUES(55,'4/4/2005',102,2952.05);
INSERT INTO C##MYUSER.ORDER_DATA VALUES(56,'5/5/2005',102,2851.74);
INSERT INTO C##MYUSER.ORDER_DATA VALUES(57,'3/4/2005',103,5848);
INSERT INTO C##MYUSER.ORDER_DATA VALUES(58,'4/5/2005',103,1853.75);
INSERT INTO C##MYUSER.ORDER_DATA VALUES(59,'5/6/2005',103,6198.99);
INSERT INTO C##MYUSER.LINEITEM VALUES(1,51,10,2);
INSERT INTO C##MYUSER.LINEITEM VALUES(2,51,20,1);
INSERT INTO C##MYUSER.LINEITEM VALUES(3,51,50,1);
INSERT INTO C##MYUSER.LINEITEM VALUES(4,52,30,2);
INSERT INTO C##MYUSER.LINEITEM VALUES(5,52,40,1);
INSERT INTO C##MYUSER.LINEITEM VALUES(6,52,20,4);
INSERT INTO C##MYUSER.LINEITEM VALUES(7,52,50,1);
INSERT INTO C##MYUSER.LINEITEM VALUES(8,53,60,1);
INSERT INTO C##MYUSER.LINEITEM VALUES(9,54,40,1);
INSERT INTO C##MYUSER.LINEITEM VALUES(10,54,50,2);
INSERT INTO C##MYUSER.LINEITEM VALUES(11,55,20,1);
INSERT INTO C##MYUSER.LINEITEM VALUES(12,55,30,3);
INSERT INTO C##MYUSER.LINEITEM VALUES(13,55,10,2);
INSERT INTO C##MYUSER.LINEITEM VALUES(14,55,50,1);
INSERT INTO C##MYUSER.LINEITEM VALUES(15,56,60,1);
INSERT INTO C##MYUSER.LINEITEM VALUES(16,56,20,3);
INSERT INTO C##MYUSER.LINEITEM VALUES(17,57,10,4);
INSERT INTO C##MYUSER.LINEITEM VALUES(18,57,40,2);
INSERT INTO C##MYUSER.LINEITEM VALUES(19,57,50,1);
INSERT INTO C##MYUSER.LINEITEM VALUES(20,58,30,5);
INSERT INTO C##MYUSER.LINEITEM VALUES(21,58,20,3);
INSERT INTO C##MYUSER.LINEITEM VALUES(22,59,60,1);
INSERT INTO C##MYUSER.LINEITEM VALUES(23,59,40,2);
INSERT INTO C##MYUSER.LINEITEM VALUES(24,59,50,3);
INSERT INTO C##MYUSER.CONTACT VALUES('homeAddress',101,'ABC Street','Edison','416-392-2932');
INSERT INTO C##MYUSER.CONTACT VALUES('officeAddress',101,'XYZ Street','New Jersey','416-221-1922');


-- specify grants to specific tables
GRANT SELECT ON C##MYUSER.PRODUCT TO C##CDC_PRIVS;
GRANT SELECT ON C##MYUSER.ORDER_DATA TO C##CDC_PRIVS;
GRANT SELECT ON C##MYUSER.LINEITEM TO C##CDC_PRIVS;
GRANT SELECT ON C##MYUSER.CUSTOMERID TO C##CDC_PRIVS;
GRANT SELECT ON C##MYUSER.CUSTOMER TO C##CDC_PRIVS;
GRANT SELECT ON C##MYUSER.CONTACT TO C##CDC_PRIVS;