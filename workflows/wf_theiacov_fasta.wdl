version 1.0

import "../tasks/task_taxonID.wdl" as taxon_ID
import "../tasks/task_ncbi.wdl" as ncbi
import "../tasks/quality_control/task_consensus_qc.wdl" as consensus_qc_task
import "../tasks/task_versioning.wdl" as versioning

workflow theiacov_fasta {
  meta {
    description: "Reference-based consensus calling for viral amplicon ont sequencing data generated on the Clear Labs platform."
  }
  input {
    String samplename
    File assembly_fasta
    String seq_method
    String input_assembly_method
    String nextclade_dataset_reference = "MN908947"
    String nextclade_dataset_tag = "2022-09-27T12:00:00Z"
    String? nextclade_dataset_name
    String organism = "sars-cov-2"
  }
  call consensus_qc_task.consensus_qc {
    input:
      assembly_fasta = assembly_fasta
  }
  if (organism == "sars-cov-2") {
    # sars-cov-2 specific tasks
    call taxon_ID.pangolin4 {
      input:
        samplename = samplename,
        fasta = assembly_fasta
    }
  }
  if (organism == "MPXV") {
    # MPXV specific tasks
  }
  if (organism == "MPXV" || organism == "sars-cov-2"){
    # tasks specific to either MPXV or sars-cov-2 
    call taxon_ID.nextclade_one_sample {
      input:
      genome_fasta = assembly_fasta,
      dataset_name = select_first([nextclade_dataset_name, organism]),
      dataset_reference = nextclade_dataset_reference,
      dataset_tag = nextclade_dataset_tag
    }
    call taxon_ID.nextclade_output_parser_one_sample {
      input:
      nextclade_tsv = nextclade_one_sample.nextclade_tsv
    }
    call ncbi.vadr {
      input:
        genome_fasta = assembly_fasta,
        assembly_length_unambiguous = consensus_qc.number_ATCG
    }
  }
  call versioning.version_capture{
    input:
  }
  output {
    # Version Capture
    String theiacov_fasta_version = version_capture.phvg_version
    String theiacov_fasta_analysis_date = version_capture.date
    # Read & Assembly Metadata
    String seq_platform = seq_method
    String assembly_method = input_assembly_method
    # Assembly QC
    Int number_N = consensus_qc.number_N
    Int assembly_length_unambiguous = consensus_qc.number_ATCG
    Int number_Degenerate = consensus_qc.number_Degenerate
    Int number_Total = consensus_qc.number_Total
    Float percent_reference_coverage = consensus_qc.percent_reference_coverage
    # Lineage Assignment
    String? pango_lineage = pangolin4.pangolin_lineage
    String? pango_lineage_expanded = pangolin4.pangolin_lineage_expanded
    String? pangolin_conflicts = pangolin4.pangolin_conflicts
    String? pangolin_notes = pangolin4.pangolin_notes
    String? pangolin_assignment_version = pangolin4.pangolin_assignment_version
    File? pango_lineage_report = pangolin4.pango_lineage_report
    String? pangolin_docker = pangolin4.pangolin_docker
    String? pangolin_versions = pangolin4.pangolin_versions
    # Clade Assigment
    File? nextclade_json = nextclade_one_sample.nextclade_json
    File? auspice_json = nextclade_one_sample.auspice_json
    File? nextclade_tsv = nextclade_one_sample.nextclade_tsv
    String? nextclade_version = nextclade_one_sample.nextclade_version
    String? nextclade_docker = nextclade_one_sample.nextclade_docker
    String nextclade_ds_tag = nextclade_dataset_tag
    String? nextclade_clade = nextclade_output_parser_one_sample.nextclade_clade
    String? nextclade_aa_subs = nextclade_output_parser_one_sample.nextclade_aa_subs
    String? nextclade_aa_dels = nextclade_output_parser_one_sample.nextclade_aa_dels
    String? nextclade_lineage = nextclade_output_parser_one_sample.nextclade_lineage
    # VADR Annotation QC
    File?  vadr_alerts_list = vadr.alerts_list
    String? vadr_num_alerts = vadr.num_alerts
    String? vadr_docker = vadr.vadr_docker
    File? vadr_fastas_zip_archive = vadr.vadr_fastas_zip_archive
  }
}
