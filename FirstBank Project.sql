Use BcBankDB

--Retrieve customer account details--
SELECT
	a.AccountID,
	c.CustomerID,
	CONCAT(c.FirstNames,  '  ', c.LastName) AS CustomerName,
	FORMAT(a.AccountOpeningDate, 'yyyy-MM-dd') AS OpeningDate,
	a.AccountTypes,
	s.StatusTypes,
	c.Email,
	c.PhoneNumber

FROM Customer c
JOIN AccountTypes a 
ON c.CustomerID=a.CustomerID
JOIN AccountStatus s
ON a.StatusID=s.StatusID
ORDER BY OpeningDate ASC;

--Retrieve customer transaction details with their other details--
SELECT
	t.TransactionID,
	t.AccountID,
	c.customerID,
	c.FirstNames + ' ' + c.LastName AS FullName,
	FORMAT(a.AccountOpeningDate, 'yyyy-MM-dd') AS OpeningDate,
	s.StatusTypes,
	t.TransactionAmount,
	ty.TransactionType,
	FORMAT(t.TransactionDate, 'yyyy-MM-dd') AS TransactionDate
FROM TransactionTable t
JOIN AccountTypes a
ON a.AccountID=t.AccountID
JOIN Customer c 
ON a.CustomerID=c.CustomerID
JOIN AccountStatus s
ON a.StatusID=s.StatusID
JOIN TransactionType ty
ON t.TransactionTypeID=ty.TransactionTypeID;


--Categorize customer transactions () into inflow and outflow. Inflow comprises deposit and Interest income
--transactions. While outflow transactions are bank charges, loan payments, POS, Transfer and Withrawals
SELECT
    a.AccountID,
    a.CustomerID,
    CONCAT(c.FirstNames, ' ', c.LastName) AS FullName,
    ISNULL(FORMAT(SUM(CASE WHEN ty.TransactionType IN ('Deposit', 'Interest Income') 
	THEN t.TransactionAmount END), '#,##0'),0) AS Inflow,
	FORMAT(SUM(CASE WHEN ty.TransactionType IN ('Bank Charges', 'Loan Payments', 'POS', 'Transfer', 'Withdrawals') 
	THEN t.TransactionAmount ELSE 0 END), '#,##0') AS Outflow
FROM 
    AccountTypes a
JOIN 
    TransactionTable t ON a.AccountID = t.AccountID
JOIN 
    TransactionType ty ON t.TransactionTypeID = ty.TransactionTypeID
JOIN 
    Customer c ON a.CustomerID = c.CustomerID
GROUP BY 
    a.AccountID, a.CustomerID, c.FirstNames, c.LastName
ORDER BY 
    SUM(CASE WHEN ty.TransactionType IN ('Deposit', 'Interest Income')
	THEN t.TransactionAmount ELSE 0 END) DESC;


--Calculate how much bank charges have been debited from customers Year on Year
  SELECT 
	FORMAT(SUM(TransactionAmount),'#,##0') BankCharges,
	YEAR (TransactionDate) Year_
  FROM TransactionTable t
  JOIN TransactionType ty 
  ON t.TransactionTypeID=ty.TransactionTypeID
  WHERE ty.TransactionType = 'Bank Charges'
  GROUP BY YEAR (TransactionDate);

--Determine customers Eligible for Loan using customers transactions. Customers who have transacted at least 4 times
-- and their total Inflow (Deposit and Interest income) is at least 2 million and their account status must be active.
 SELECT
	t.AccountID,
	ts.StatusTypes,
	COUNT(t.TransactionID) AS TransactionCount,
	FORMAT(Sum(t.TransactionAmount), '#,##0') Inflow,
	CASE 
	WHEN Sum(t.TransactionAmount) < 5000000 THEN 'Payday Loan'
	WHEN Sum(t.TransactionAmount) BETWEEN 5000000 AND 9999999 THEN 'Personal Loan'
	WHEN Sum(t.TransactionAmount) BETWEEN 10000000 AND 14999999 THEN 'Auto Loan'
	WHEN Sum(t.TransactionAmount) BETWEEN 15000000 AND 19999999 THEN 'SME Loan'
	ELSE 'Asset Financing'
	END AS LoanType
 FROM TransactionTable t
 LEFT JOIN TransactionType ty
 ON t.TransactionTypeID=ty.TransactionTypeID
 LEFT JOIN AccountTypes a
 ON a.AccountID=t.AccountID
 LEFT JOIN AccountStatus ts
 ON a.StatusID=ts.StatusID
 WHERE ty.TransactionType in ('Deposit','Interest Income') AND ts.StatusTypes= 'Active'
 GROUP BY t.AccountID, ts.StatusTypes
 HAVING COUNT(t.TransactionID) >=4 AND Sum(t.TransactionAmount) > 2000000
 ORDER BY Sum(t.TransactionAmount) ASC;
 

 --Reteive the full details of customers eligible for loan
 -- Customer details to be included are customer full name, phone number and email for contact Campaign
 --Finally Draft a campaign plan that will be sent to customers to opt for the loan product
  SELECT
	t.AccountID,
	c.FirstNames + ' ' + c.LastName AS FullName,
	c.Email,
	c.PhoneNumber,
	ts.StatusTypes,
	COUNT(t.TransactionID) AS TransactionCount,
	FORMAT(Sum(t.TransactionAmount), '#,##0') Inflow,
	CASE 
	WHEN Sum(t.TransactionAmount) < 5000000 THEN 'Payday Loan'
	WHEN Sum(t.TransactionAmount) BETWEEN 5000000 AND 9999999 THEN 'Personal Loan'
	WHEN Sum(t.TransactionAmount) BETWEEN 10000000 AND 14999999 THEN 'Auto Loan'
	WHEN Sum(t.TransactionAmount) BETWEEN 15000000 AND 19999999 THEN 'SME Loan'
	ELSE 'Asset Financing'
	END AS LoanType
 FROM TransactionTable t
 LEFT JOIN TransactionType ty
 ON t.TransactionTypeID=ty.TransactionTypeID
 LEFT JOIN AccountTypes a
 ON a.AccountID=t.AccountID
 LEFT JOIN AccountStatus ts
 ON a.StatusID=ts.StatusID
 LEFT JOIN Customer c
 ON c.CustomerID=a.CustomerID
 WHERE ty.TransactionType in ('Deposit','Interest Income') AND ts.StatusTypes= 'Active'
 GROUP BY t.AccountID, ts.StatusTypes, c.FirstNames + ' ' + c.LastName, c.Email, c.PhoneNumber
 HAVING COUNT(t.TransactionID) >=4 AND Sum(t.TransactionAmount) > 2000000
 ORDER BY Sum(t.TransactionAmount) ASC;


 --Retrieve customer details in a format that seperates inflow from outflow and shows account balance,
 --Commenting on amy anormalies found.
SELECT
    Trans.AccountID,
    c.CustomerID,
    c.FirstNames + ' ' + c.LastName AS FullName,
    FORMAT(ISNULL(Inflow, 0), '#,##0') AS Inflow,
    FORMAT(Outflow, '#,##0') AS Outflow, 
    FORMAT(ISNULL(Inflow, 0) - Outflow, '#,##0') AS AccountBalFormatted
FROM
    (
       SELECT
            a.AccountID,
            a.CustomerID,
             (
                SELECT
                SUM(t.TransactionAmount) AS Inflow
                FROM TransactionTable t
                LEFT JOIN TransactionType ty ON t.TransactionTypeID = ty.TransactionTypeID
                WHERE ty.TransactionType IN ('Deposit', 'Interest Income')
                AND a.AccountID = t.AccountID
                ) AS Inflow,
             (
                SELECT
                SUM(t.TransactionAmount ) AS Outflow
                FROM TransactionTable t
                LEFT JOIN TransactionType ty ON t.TransactionTypeID = ty.TransactionTypeID
                WHERE ty.TransactionType IN ('Bank Charges', 'Loan Payments', 'POS', 'Transfer', 'Withdrawals')
                AND t.AccountID = a.AccountID
                ) AS Outflow
            FROM AccountTypes a
    ) AS Trans
JOIN Customer c
ON Trans.CustomerID = c.CustomerID
ORDER BY ISNULL(Inflow, 0) - Outflow ASC; 


 --Identify customers with the highest and least account balance
WITH CustomerAccountBalances AS (
    SELECT
        Trans.AccountID,
        c.CustomerID,
        c.FirstNames + ' ' + c.LastName AS FullName,
        ISNULL(Inflow, 0) AS Inflow,
        Outflow, 
		ISNULL(Inflow, 0) - Outflow AS AccountBal
    FROM
        (
          SELECT
            a.AccountID,
            a.CustomerID,
            (
              SELECT
              SUM(t.TransactionAmount ) AS Inflow
              FROM TransactionTable t
              LEFT JOIN TransactionType ty ON t.TransactionTypeID = ty.TransactionTypeID
              WHERE ty.TransactionType IN ('Deposit', 'Interest Income')
              AND a.AccountID = t.AccountID
                ) AS Inflow,
           (
             SELECT
             SUM(t.TransactionAmount) AS Outflow
             FROM TransactionTable t
             LEFT JOIN TransactionType ty ON t.TransactionTypeID = ty.TransactionTypeID
             WHERE ty.TransactionType IN ('Bank Charges', 'Loan Payments', 'POS', 'Transfer', 'Withdrawals')
             AND t.AccountID = a.AccountID
                ) AS Outflow
            FROM AccountTypes a
        ) AS Trans
    JOIN Customer c ON Trans.CustomerID = c.CustomerID
)
SELECT
    CustomerID,
    FullName,
    FORMAT(Inflow, '#,##0') Inflow,
    FORMAT(Outflow , '#,##0') Outflow,
    FORMAT(AccountBal , '#,##0') AccountBal
FROM
    (
        SELECT
            CustomerID,
            FullName,
            Inflow,
            Outflow,
            AccountBal,
            ROW_NUMBER() OVER (ORDER BY AccountBal DESC) AS RankHighest,
            ROW_NUMBER() OVER (ORDER BY AccountBal ASC) AS RankLowest
        FROM
            CustomerAccountBalances
    ) AS RankedAccountBalances
WHERE
    RankHighest = 1 OR RankLowest = 1;


 --Retrieve total deposit amount for each Customer, Identifying the top 20 account type with the highest Inflow
 --These top 20 accounts will be recieving a loyalty benefit campaign.
SELECT TOP 20
    a.AccountID,
    a.CustomerID,
    CONCAT(c.FirstNames, ' ', c.LastName) AS FullName,
    FORMAT(SUM(CASE WHEN ty.TransactionType IN ('Deposit', 'Interest Income') 
	THEN t.TransactionAmount ELSE 0 END), '#,##0') AS Inflow
FROM 
    AccountTypes a
JOIN 
    TransactionTable t ON a.AccountID = t.AccountID
JOIN 
    TransactionType ty ON t.TransactionTypeID = ty.TransactionTypeID
JOIN 
    Customer c ON a.CustomerID = c.CustomerID
GROUP BY 
    a.AccountID, a.CustomerID, c.FirstNames, c.LastName
ORDER BY 
    SUM(CASE WHEN ty.TransactionType IN ('Deposit', 'Interest Income')
	THEN t.TransactionAmount ELSE 0 END) DESC;

 --Identify unique customers without cards so that a campaign can be sent to them to get cards.
 SELECT
	a.AccountID,
	c.CustomerID,
	CONCAT(c.FirstNames,  '  ', c.LastName) AS CustomerName,
	a.AccountTypes,
	c.Email,
	c.PhoneNumber

FROM AccountTypes a 
JOIN Customer c
ON c.CustomerID=a.CustomerID
JOIN AccountStatus s
ON a.StatusID=s.StatusID
WHERE a.AccountID Not In (SELECT AccountID FROM Cards);


--Identify customers whose accounts are inactive and dormant for reactivations.
SELECT
	a.AccountID,
	c.CustomerID,
	CONCAT(c.FirstNames,  '  ', c.LastName) AS CustomerName,
	FORMAT(a.AccountOpeningDate, 'yyyy-MM-dd') AS OpeningDate,
	a.AccountTypes,
	s.StatusTypes,
	c.Email,
	c.PhoneNumber

FROM Customer c
JOIN AccountTypes a 
ON c.CustomerID=a.CustomerID
JOIN AccountStatus s
ON a.StatusID=s.StatusID
WHERE s.StatusTypes IN ('Inactive', 'Dormant');

 --Do an RFM analysis to segment customers using SQL
 SELECT
    t.AccountID,
	CONCAT(c.FirstNames,  '  ', c.LastName) AS CustomerName,
    DATEDIFF(DAY, MAX(t.TransactionDate), '2024-01-01') AS Recency,
    COUNT(DISTINCT t.TransactionID) AS Frequency,
    FORMAT (SUM(CASE WHEN t.TransactionAmount > 0 THEN t.TransactionAmount ELSE 0 END),'#,##0') AS Monetary,
	CONVERT(date, MAX(t.TransactionDate)) LastTransactionDate
FROM
    TransactionTable t
	JOIN AccountTypes a 
	ON t.AccountID=a.AccountID
	Join Customer c
	ON a.CustomerID=c.CustomerID
GROUP BY
    t.AccountID, CONCAT(c.FirstNames,  '  ', c.LastName)
	ORDER BY Recency ASC, Frequency DESC, 
	SUM(CASE WHEN t.TransactionAmount > 0 THEN t.TransactionAmount ELSE 0 END) DESC;
