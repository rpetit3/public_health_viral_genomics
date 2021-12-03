version 1.0

import "../tasks/task_versioning.wdl" as versioning

workflow freyja_plot {
  input {
    Array[String] samplename
    Array[File] freyja_demixed
    Array[String]? collection_date
    String freyja_plot_name
  }
  call freyja_plot_task {
    input:
      samplename = samplename,
      freyja_demixed = freyja_demixed,
      collection_date = collection_date,
      freyja_plot_name = freyja_plot_name   
  }
  call versioning.version_capture{
    input:
  }
  output {
    String freyja_plot_wf_version = version_capture.phvg_version
    String freyja_plot_wf_analysis_date = version_capture.date
    
    File freyja_plot = freyja_plot_task.freyja_plot
    }
}

task freyja_plot_task {
  input {
    Array[String] samplename
    Array[File] freyja_demixed
    Array[String]? collection_date
    Boolean plot_lineages=true
    Boolean plot_time=false
    String plot_time_interval="MS"
    Int plot_day_window=14 
    String freyja_plot_name
    String docker = "staphb/freyja:1.2"
  }
  command <<<
  freyja_demixed_array="~{sep=' ' freyja_demixed}"
  samplename_array="~{sep=' ' samplename}"
  samplename_array_len=$(echo "${#samplename_array[@]}")

  if ~{plot_time}; then
    # create timedate metadata sheet
    collection_date_array="~{sep=' ' collection_date}"
    collection_date_array_len=$(echo "${#collection_date_array[@]}")

    if [ "$samplename_array_len" -ne "$collection_date_array_len" ]; then
      echo "ERROR: Missing collection date. Samplename array (length: $samplename_array_len) and collection date array (length: $collection_date_array_len) are of unequal length." >&2
      exit 1
    else 
      echo "Samplename array (length: $samplename_array_len) and collection date array (length: $collection_date_array_len) are of equal length." >&2.
    fi
    
    echo "Sample,sample_collection_datetime" > freyja_times_metadata.csv
    
    for index in ${!samplename_array[@]}; do
      samplename=${samplename_array[$index]}
      collection_date=${collection_date_array[$index]}
      echo "${samplename},${collection_date}" >> freyja_times_metadata.csv
    done
    
    plot_options="--times freyja_times_metadata.csv"
    
    if [ ~{plot_time_interval} == "D" ]; then
      plot_options="${interval_option} --interval D --windowsize ~{plot_day_window}"
    elif [ ~{plot_time_interval} == "MS" ]; then
      plot_options="${interval_option} --interval MS"
    else
      echo "ERROR: plot time interval value (~{plot_time_interval}) not recognized. Must be either \"D\" (days) or \"MS\" (months)" >&2
      exit 1
    fi
    
  fi
  
  # move all assemblies into single directory and aggregate files
  mkdir ./demixed_files/
  echo "mv ${freyja_demixed_array[@]} demixed_files/"
  mv ${freyja_demixed_array[@]} ./demixed_files/
  
  freyja aggregate \
      ./demixed_files/ \
      --output demixed_aggregate.tsv
  
  # create freya plot 
  echo "Running: freyja plot demixed_aggregate.tsv --output ~{freyja_plot_name}.pdf ${plot_options}"
  freyja plot \
      ~{true='--lineages' false ='' plot_lineages} \
      demixed_aggregate.tsv \
      --output ~{freyja_plot_name}.pdf \
      ${plot_options}
      
  
  >>>
  output {
    File freyja_plot = "~{freyja_plot_name}.pdf"
  }
  runtime {
    memory: "4 GB"
    cpu: 2
    docker: "~{docker}"
    disks: "local-disk 100 HDD"
  }
}