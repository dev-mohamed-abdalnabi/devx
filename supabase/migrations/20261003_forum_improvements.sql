-- المنتدى: قبول سبب البلاغ «hate» الذي تعرضه الواجهة (كان يُرفض من القيد).
alter table public.reports drop constraint if exists reports_reason_check;
alter table public.reports add constraint reports_reason_check
  check (reason in ('spam','harassment','hate','misinformation','inappropriate','other'));
