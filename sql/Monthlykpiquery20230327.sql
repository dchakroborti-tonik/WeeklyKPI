-- create table `dap_ds_poweruser_playground.collection_Monthly_kpi_v4` as 
insert into `dap_ds_poweruser_playground.collection_Monthly_kpi_v4` 
WITH
  dt AS (
  SELECT
    DATE('2023-04-01') WkstartDate,
    DATE('2023-04-16') WkendDate),
disb as (select distinct disbursementDateTime, customerId, loanType, loanAccountNumber, SUBSTR(mobileNo, -10) as mobileno , loanPaidStatus
, row_number() over(partition by SUBSTR(mobileNo, -10) order by SUBSTR(mobileNo, -10))rnk
from `risk_credit_mis.loan_master_table`, dt where date_trunc(disbursementDateTime, day) between dt.WkstartDate and dt.WkendDate and coalesce(loanPaidStatus, 'NA') not in ('Settled','Completed')
)
,
wc1 as 
(
SELECT
  dt.WkstartDate,
  dt.WkendDate,
  Genesys_call_id,
  callDatetime,
  COALESCE(IS_APC, 0) APC,
  COALESCE(IS_RPC, 0) RPC,
  COALESCE(IS_PTP,0) PTP,
  RIGHT(mobileNumber, 10) mobileNumber,
  g.campaignName,
  g.agentGroup,
  g.agentFullName,
  g.employeeId,
  g.connected,
  g.notConnected,
  g.callResult,
  ROW_NUMBER() OVER(PARTITION BY Genesys_call_id ORDER BY callDatetime DESC, COALESCE(IS_APC, 0), COALESCE(IS_RPC, 0), COALESCE(IS_PTP, 0))rnk
FROM
  `risk_credit_mis.call_attempt_history_gensys` g,  dt
LEFT JOIN
  `dap_ds_poweruser_playground.campaignmaster` cm
ON
  UPPER(cm.Campaignname) = UPPER(g.campaignName)
INNER JOIN disb ON  SUBSTR(disb.mobileNo, -10) = SUBSTR(CAST(g.mobileNumber AS string), -10)
WHERE
  cm.reference = 'WC'
  and disb.rnk = 1
)
, 
wc as 
(select wc1.WkstartDate, wc1.WkendDate, Genesys_call_id,
callDatetime,
APC,
RPC,
PTP,
case when APC = 1 then mobileNumber end apc_m,
case when RPC = 1 then mobileNumber end rpc_m,
case when PTP = 1 then mobileNumber end ptp_m,
mobileNumber,
campaignName,
agentGroup,
agentFullName,
employeeId,
connected,
notConnected,
callResult,
rnk,
from wc1 
where rnk = 1
)
,
wcbase as 
( 
select wc.WkstartDate, wc.WkendDate,
 Genesys_call_id,
callDatetime,
APC,
RPC,
PTP,
mobileNumber,
campaignName,
agentGroup,
agentFullName,
employeeId,
connected,
notConnected,
callResult,
rnk,
apc_m,
rpc_m,
ptp_m
from wc
)
, 
cd AS (
  SELECT
    customer_id,
    new_mobile_number,
    ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY change_date)rnk
  FROM
    `risk_credit_mis.customer_contact_details`
  WHERE
    ACTIVE = 'Y')
  ,
  buck1 as 
  (select distinct dt.WkstartDate, dt.WkendDate, lbfrc.loanAccountNumber, lbfrc.loanStatus, lbfrc.bucketDate, lbfrc.Max_current_DPD as DPD, lmt.customerId, right(cd.new_mobile_number, 10) newmobilenumber
  , row_number() over(partition by lbfrc.loanAccountNumber order by lbfrc.bucketDate desc) buck1rnk
  from `risk_credit_mis.loan_bucket_flow_report_core` lbfrc, dt 
  left join `risk_credit_mis.loan_master_table` lmt on lmt.loanAccountNumber = lbfrc.loanAccountNumber
  left join cd on cd.customer_id = lmt.customerId
  where date(bucketDate) between  date(dt.WkstartDate) and  date(dt.WkendDate)
  and coalesce(lbfrc.Max_current_DPD, 0) between 1 and 30 
  and date(lbfrc.firstDueDate) <= date(current_date())
  and lbfrc.loanStatus = 'In Arrears'
  and cd.rnk = 1
  )
  ,
buck1cr1 as 
(select distinct
 dt.WkstartDate,
  dt.WkendDate,
  g.Genesys_call_id,
  g.callDatetime,
  COALESCE(g.IS_APC, 0) APC,
  COALESCE(g.IS_RPC, 0) RPC,
  COALESCE(g.IS_PTP,0) PTP,
  RIGHT(g.mobileNumber, 10) mobileNumber,
  buck1.newmobilenumber mobilefrombuckettable,
  g.campaignName,
  g.agentGroup,
  g.agentFullName,
  g.employeeId,
  g.connected,
  g.notConnected,
  g.callResult, 
  buck1.loanAccountNumber,
  buck1.DPD,
  case when g.IS_APC = 1 then g.mobileNumber end apc_m,
  case when g.IS_RPC = 1 then g.mobileNumber end rpc_m,
  case when g.IS_PTP = 1 then mobileNumber end ptp_m,
  ROW_NUMBER() OVER(PARTITION BY g.Genesys_call_id ORDER BY g.callDatetime DESC, COALESCE(g.IS_APC, 0), COALESCE(g.IS_RPC, 0), COALESCE(g.IS_PTP, 0))rnk 
from  `risk_credit_mis.call_attempt_history_gensys` g,  dt
inner join buck1 on buck1.newmobilenumber = right(g.mobileNumber,10)
LEFT JOIN
  `dap_ds_poweruser_playground.campaignmaster` cm ON  UPPER(cm.Campaignname) = UPPER(g.campaignName)
where cm.Reference = 'COLL' and cm.Subcategory = 'SOFT'
AND DATE(g.callDatetime) BETWEEN DATE(dt.WkstartDate) AND DATE(dt.WkendDate)
and buck1.buck1rnk = 1
)
,
buck1cr1base as 
(select buck1cr1.WkstartDate, buck1cr1.WkendDate, buck1cr1.Genesys_call_id, buck1cr1.callDatetime
, buck1cr1.mobileNumber
, buck1cr1.mobilefrombuckettable
, buck1cr1.campaignName
, buck1cr1.agentGroup
, buck1cr1.agentFullName
, buck1cr1.employeeId
, buck1cr1.connected
, buck1cr1.notConnected
, buck1cr1.callResult
, buck1cr1.loanAccountNumber
, buck1cr1.apc_m 
, buck1cr1.rpc_m
, buck1cr1.ptp_m 
, buck1cr1.DPD
, buck1cr1.rnk 
 from buck1cr1 where rnk = 1
)
,
buck1end as 
(select distinct dt.WkstartDate, dt.WkendDate, lbfrc.loanAccountNumber, lbfrc.loanStatus, lbfrc.bucketDate, lbfrc.Max_current_DPD as DPD, lmt.customerId, right(cd.new_mobile_number, 10) newmobilenumber
from `risk_credit_mis.loan_bucket_flow_report_core` lbfrc, dt 
left join `risk_credit_mis.loan_master_table` lmt on lmt.loanAccountNumber = lbfrc.loanAccountNumber
left join cd on cd.customer_id = lmt.customerId
where date(bucketDate) = date(dt.WkendDate)
and date(lbfrc.firstDueDate) <= date(current_date())
and cd.rnk = 1
)
, 
ptpstatus as 
(select max(dt.WkstartDate)WkstartDate, max(dt.WkendDate)WkendDate, cps.Loan_account_no, sum(case when coalesce(cps.PTP_Status, 0) = 1 then 1 else 0 end) ptpstatus 
from `risk_credit_mis.collection_ptp_status`  cps, dt where coalesce(PTP_Status, 0) = 1
and date(contact_date) between dt.WkstartDate and dt.WkendDate
group by cps.Loan_account_no
)
,
payments as (select * from `risk_credit_mis.loan_installments_table` , dt where date(lastPaymentDate) between dt.WkstartDate and dt.WkendDate),
buck1normalized as 
(select buck1.WkstartDate, buck1.WkendDate, buck1.loanAccountNumber , buck1.DPD weekstartDPD, buck1end.DPD weekendDPD
, case when buck1.loanAccountNumber in (select distinct Loan_account_no from `risk_credit_mis.collection_ptp_status` where PTP_Due_Date is not null) then buck1.newmobilenumber end ptp_received
, case when buck1.loanAccountNumber in (select distinct Loan_account_no from ptpstatus) then buck1.newmobilenumber end Kept_ptp
, case when coalesce(buck1.DPD, 0) between 1 and 30 and coalesce(buck1end.DPD, 0) = 0 and buck1.loanAccountNumber in (select distinct Loan_account_no from ptpstatus) then buck1.newmobilenumber end Normalized 
, case when coalesce(buck1.DPD, 0) between 1 and 30 and coalesce(buck1end.DPD, 0) = 0 and buck1.loanAccountNumber not in (select distinct Loan_account_no from ptpstatus) then buck1.newmobilenumber end Normalizedwithoutptp 
, case when coalesce(buck1.DPD, 0) between 1 and 30 and coalesce(buck1end.DPD, 0) <= 30 and buck1.loanAccountNumber in (select loanAccountNumber from payments) then buck1.newmobilenumber end Normalized_greg 
, case when coalesce(buck1.DPD, 0) between 1 and 30 then buck1.newmobilenumber end Normalized_greg_denominator
, case when coalesce(buck1.DPD, 0) between 1 and 30 and coalesce(buck1end.DPD, 0) <= 30 and buck1.loanAccountNumber not in (select distinct Loan_account_no from ptpstatus) then buck1.newmobilenumber end Normalizedwithoutptp_greg
from buck1
left join buck1end on buck1.loanAccountNumber =  buck1end.loanAccountNumber
)
,
buck2 as 
(select dt.WkstartDate, dt.WkendDate, lbfrc.loanAccountNumber, lbfrc.loanStatus, lbfrc.bucketDate, lbfrc.Max_current_DPD as DPD, lmt.customerId, right(cd.new_mobile_number, 10) newmobilenumber
, row_number() over(partition by lbfrc.loanAccountNumber order by lbfrc.bucketDate desc) buck2rnk
from `risk_credit_mis.loan_bucket_flow_report_core` lbfrc, dt 
left join `risk_credit_mis.loan_master_table` lmt on lmt.loanAccountNumber = lbfrc.loanAccountNumber
left join cd on cd.customer_id = lmt.customerId
where date(bucketDate)  between  date(dt.WkstartDate) and  date(dt.WkendDate)
and coalesce(lbfrc.Max_current_DPD, 0) between 31 and 60 
and date(lbfrc.firstDueDate) <= date(current_date())
and lbfrc.loanStatus = 'In Arrears'
and cd.rnk = 1
)
,
buck2cr1 as 
(select   dt.WkstartDate,
  dt.WkendDate,
  g.Genesys_call_id,
  g.callDatetime,
  COALESCE(g.IS_APC, 0) APC,
  COALESCE(g.IS_RPC, 0) RPC,
  COALESCE(g.IS_PTP,0) PTP,
  RIGHT(g.mobileNumber, 10) mobileNumber,
  buck2.newmobilenumber mobilefrombuckettable,
  g.campaignName,
  g.agentGroup,
  g.agentFullName,
  g.employeeId,
  g.connected,
  g.notConnected,
  g.callResult, 
  buck2.loanAccountNumber,
  buck2.DPD,
  case when g.IS_APC = 1 then g.mobileNumber end apc_m,
  case when g.IS_RPC = 1 then g.mobileNumber end rpc_m,
  case when g.IS_PTP = 1 then mobileNumber end ptp_m,
  ROW_NUMBER() OVER(PARTITION BY g.Genesys_call_id ORDER BY g.callDatetime DESC, COALESCE(g.IS_APC, 0), COALESCE(g.IS_RPC, 0), COALESCE(g.IS_PTP, 0))rnk 
from  `risk_credit_mis.call_attempt_history_gensys` g,  dt
inner join buck2 on buck2.newmobilenumber = right(g.mobileNumber,10)
LEFT JOIN
  `dap_ds_poweruser_playground.campaignmaster` cm ON  UPPER(cm.Campaignname) = UPPER(g.campaignName)
where cm.Reference = 'COLL' 
AND DATE(g.callDatetime) BETWEEN DATE(dt.WkstartDate) AND DATE(dt.WkendDate)
and buck2.buck2rnk = 1
)
,buck2cr1base as 
(select buck2cr1.WkstartDate, buck2cr1.WkendDate, buck2cr1.Genesys_call_id, buck2cr1.callDatetime
, buck2cr1.mobileNumber
, buck2cr1.mobilefrombuckettable
, buck2cr1.campaignName
, buck2cr1.agentGroup
, buck2cr1.agentFullName
, buck2cr1.employeeId
, buck2cr1.connected
, buck2cr1.notConnected
, buck2cr1.callResult
, buck2cr1.loanAccountNumber
, buck2cr1.apc_m 
, buck2cr1.rpc_m
, buck2cr1.ptp_m 
, buck2cr1.DPD
, buck2cr1.rnk 
 from buck2cr1 where rnk = 1
)
,
buck2normalized as 
(select buck2.WkstartDate, buck2.WkendDate, buck2.loanAccountNumber , buck2.DPD weekstartDPD, buck1end.DPD weekendDPD
, case when buck2.loanAccountNumber in (select distinct Loan_account_no from `risk_credit_mis.collection_ptp_status` where PTP_Due_Date is not null) then buck2.newmobilenumber end ptp_received
, case when buck2.loanAccountNumber in (select distinct Loan_account_no from ptpstatus) then buck2.newmobilenumber end Kept_ptp
, case when coalesce(buck2.DPD, 0) between 31 and 60 and coalesce(buck1end.DPD, 0) = 0 and buck2.loanAccountNumber in (select distinct Loan_account_no from ptpstatus) then buck2.newmobilenumber end Normalized 
, case when coalesce(buck2.DPD, 0) between 31 and 60 and coalesce(buck1end.DPD, 0) = 0 and buck2.loanAccountNumber not in (select distinct Loan_account_no from ptpstatus) then buck2.newmobilenumber end Normalizedwithoutptp 
, case when coalesce(buck2.DPD, 0) between 31 and 60 then buck2.newmobilenumber end Normalized_greg_denominator 
, case when coalesce(buck2.DPD, 0) between 31 and 60 and coalesce(buck1end.DPD, 0) <= 60 and buck2.loanAccountNumber in (select loanAccountNumber from payments) then buck2.newmobilenumber end Normalized_greg 
, case when coalesce(buck2.DPD, 0) between 31 and 60 and coalesce(buck1end.DPD, 0) <= 60 and buck2.loanAccountNumber not in (select distinct Loan_account_no from ptpstatus) then buck2.newmobilenumber end Normalizedwithoutptp_greg 
from buck2
left join buck1end on buck2.loanAccountNumber =  buck1end.loanAccountNumber
)
,
Ptp_payment as 
(select date_trunc(contact_date, day) contact_date, Loan_account_no, Phone_no, sum(case when coalesce(PTP_Status, 0) > 0 then PTP_Payment_amount else 0 end) ptppaymentamount 
from prj-prod-dataplatform.risk_credit_mis.collection_ptp_status group by date_trunc(contact_date, day), Loan_account_no, Phone_no
)
,
buck1ptpamt as 
(select distinct buck1normalized.WkstartDate,buck1normalized.WkendDate,loanAccountNumber
, case when Normalized_greg is not null then (select sum(ptppaymentamount) from Ptp_payment where Loan_account_no = buck1normalized.loanAccountNumber and date(contact_date) between dt.WkstartDate and dt.WkendDate) else 0 end ptpamount_normalized  
,(select sum(ptppaymentamount) from Ptp_payment where Loan_account_no = buck1normalized.loanAccountNumber and date(contact_date) between dt.WkstartDate and dt.WkendDate)  ptpamount  
from buck1normalized, dt)
,
buck2ptpamt as 
(select distinct buck2normalized.WkstartDate,buck2normalized.WkendDate,loanAccountNumber
, case when Normalized is not null then (select sum(ptppaymentamount) from Ptp_payment where Loan_account_no = buck2normalized.loanAccountNumber and date(contact_date) 
between dt.WkstartDate and dt.WkendDate) else 0 end ptpamount_normalized  
, (select sum(ptppaymentamount) from Ptp_payment where Loan_account_no = buck2normalized.loanAccountNumber and date(contact_date) 
between dt.WkstartDate and dt.WkendDate)  ptpamount 
from buck2normalized, dt),
fte as 
(select distinct agentFullName FROM
  `risk_credit_mis.call_attempt_history_gensys` g,
  dt
LEFT JOIN
  `dap_ds_poweruser_playground.campaignmaster` cm
ON
  UPPER(cm.Campaignname) = UPPER(g.campaignName)
WHERE
   DATE(g.callDatetime) BETWEEN DATE(dt.WkstartDate)  AND DATE(WkendDate)
   and cm.reference in ('REM', 'COLL', 'WC')),
LUM as 
(select distinct loanAccountNumber from `prj-prod-dataplatform.risk_credit_mis.loan_master_table`, dt where flagDisbursement = 1 and date_trunc(disbursementDateTime, day) < dt.WkstartDate
and loanPaidStatus not in ('Written Off','Completed', 'Settled')),
aw as 
(select bucketDate, loanAccountNumber from `risk_credit_mis.loan_bucket_flow_report_core`, dt where coalesce(Max_current_DPD ,0) between 1 and 179 and date(bucketDate) = dt.WkstartDate and loanStatus not in ('Written Off','Completed', 'Settled'))
select 
(select WkstartDate from dt) WkstartDate,
(select WkendDate from dt) WkendDate,
(select count(distinct apc_m) from wc) apc_wc_connected,
(select count(distinct mobileNumber) wccontactrate from wc) wccalled,
(select count(distinct apc_m) from buck1cr1base) bucket1contacted,
(select count(distinct mobilefrombuckettable) Bucket1callcontactrate from buck1cr1base where mobilefrombuckettable is not null)bucketcallcontacted,
(select count(distinct Normalized_greg) from buck1normalized) bucket1normalized_greg,
(select count(distinct Normalized_greg_denominator) from buck1normalized) bucket1normalized_denominator,
(select count(distinct Normalized_greg_denominator) from buck2normalized) bucket2normalized_denominator,
(select count(distinct Normalized_greg) from buck2normalized) bucket2normalized_greg,
(select count(distinct ptp_received) from buck1normalized)+(select count(distinct ptp_received) from buck2normalized) ptp_received,
(select count(distinct Kept_ptp) from buck1normalized) + (select count(distinct Kept_ptp) from buck2normalized) kept_ptp,
(select sum(ptpamount) from buck1ptpamt)bucket1ptppmt,
(select sum(ptpamount) from buck2ptpamt) bucket2ptppmt,
(select count(distinct agentFullName) from fte)FTE,
(select count(distinct loanAccountNumber) from LUM) total_accounts,
(select count(distinct loanAccountNumber) from aw) active_works
