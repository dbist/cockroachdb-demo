# Multiregion serverless


drop table new_order;
drop table order_line;
drop table "order";
drop table customer;
drop table history;
drop table stock;
drop table district;
drop table warehouse;
drop table item;


## US East 1

cockroach sql --url "postgresql://artem:changeme1234567@artem-serverless-mr-10.gww.gcp-us-east1.cockroachlabs.cloud:26257/defaultdb?sslmode=verify-full"

## US West 2

cockroach sql --url "postgresql://artem:changeme1234567@artem-serverless-mr-10.gww.gcp-us-west2.cockroachlabs.cloud:26257/defaultdb?sslmode=verify-full"


## Europe West 1

cockroach sql --url "postgresql://artem:changeme1234567@artem-serverless-mr-10.gww.gcp-europe-west1.cockroachlabs.cloud:26257/defaultdb?sslmode=verify-full"


## init workload

cockroach workload init tpcc \
 --db defaultdb \
 --warehouses 100 \
 "postgresql://artem:changeme1234567@artem-serverless-mr-10.gww.gcp-us-east1.cockroachlabs.cloud:26257/defaultdb?sslmode=verify-full"

## run workload

cockroach workload run tpcc --db defaultdb "postgresql://artem:changeme1234567@artem-serverless-mr-10.gww.gcp-us-east1.cockroachlabs.cloud:26257/defaultdb?sslmode=verify-full" \
 --active-warehouses 100 \
 --warehouses 100 \
 --duration 60m \
 --idle-conns 100 \
 --tolerate-errors \
 --workers 1000 


cockroach workload run tpcc --db defaultdb "postgresql://artem:changeme1234567@artem-serverless-mr-10.gww.gcp-europe-west1.cockroachlabs.cloud:26257/defaultdb?sslmode=verify-full" \
 --active-warehouses 100 \
 --warehouses 100 \
 --duration 60m \
 --idle-conns 100 \
 --tolerate-errors \
 --workers 1000 