.SILENT:
input_sanity_check:
	if [ $(op_log_dir) ]; then \
	    python inputs_sanity_check.py -f $(test_list) -o $(op_log_dir); \
	else \
	    python inputs_sanity_check.py -f $(test_list); \
	fi
