clc
clearvars
fclose all;

%% The main functions, written in script format (live script)

%interacts with engine to create circuit data structure
run_case1_MLX;

%creates the preliminary summary tables (one for lines and one for loads)
summarytable_ODSS_MLX;

%create the adjacency matrix
make_aMatrix_ODSS_MLX;

%calcs some metrics for transformers (downstream)
xformer_loads_ODSS_MLX;

%plots the feeder
plot_aMatrix_MLX;

%pulls the additional metrics/stats calculated into the summary tables
final_summarytable_ODSS_MLX;

%calcs the aggregate metrics
agg_metrics_shared_ODSS_MLX;

%saves summary statistics into an excel sheet
table_contents_ODSS_MLX;



