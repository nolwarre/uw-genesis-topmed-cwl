#!/usr/bin/env cwl-runner

class: CommandLineTool
cwlVersion: v1.0
label: UW GENESIS null_model.R
doc: |
  # Null model
  Association tests are done with a mixed model if a kinship matrix or GRM 
  (`relatedness_matrix_file`) is given in the config file. If 
  `relatedness_matrix_file` is `NA` or missing, testing is done with a fixed 
  effects model.  

  When combining samples from groups with different variances for a trait 
  (e.g., study or ancestry group), it is recommended to allow the null model to 
  fit heterogeneous variances by group using the parameter `group_var`. The 
  default pipeline options will then result in the following procedure:

  1. Fit null mixed model with outcome variable
      - Allow heterogeneous variance by `group_var`
      - Include covariates and PCs as fixed effects
      - Include kinship as random effect
  2. Inverse normal transform marginal residuals (if `inverse_normal = TRUE`)
  3. Rescale variance to match original (if `rescale_variance = "marginal"` or `"varcomp"`)
  4. Fit null mixed model using transformed residuals as outcome
      - Allow heterogeneous variance by `group_var`
      - Include covariates and PCs as fixed effects
      - Include kinship as random effect

$namespaces:
  sbg: https://sevenbridges.com

requirements:
  DockerRequirement:
    dockerPull: uwgac/topmed-master:2.6.0
  ResourceRequirement:
    coresMin: 2
  InitialWorkDirRequirement:
    listing:
    - $(inputs.phenotype_file)
    - $(inputs.pca_file)
    - $(inputs.relatedness_matrix)
    - entryname: null_model.config
      entry: |
        # From https://github.com/UW-GAC/analysis_pipeline#null-model
        out_prefix $(inputs.out_prefix)
        phenotype_file $(inputs.phenotype_file.basename)
        outcome $(inputs.outcome)
        binary $(inputs.outcome_is_binary)
        ${
          if(inputs.pca_file) 
            return "pca_file " + inputs.pca_file.basename
          else return ""
        }
        ${
          if(inputs.relatedness_matrix) 
            return "relatedness_matrix " + inputs.relatedness_matrix.basename
          else return ""
        }
        ${
          if(inputs.covariates) 
            return "covars " + inputs.covariates
          else return ""
        }
    - entryname: script.sh
      entry: |
        set -x
        cat null_model.config

        Rscript /usr/local/analysis_pipeline/R/null_model.R null_model.config
        Rscript /usr/local/analysis_pipeline/R/null_model_report.R null_model.config --version 2.6.0
        ls -al

        DATADIR=$(inputs.out_prefix)_datadir
        mkdir $DATADIR
        mv $(inputs.out_prefix)*.RData $DATADIR/

        REPORTDIR=$(inputs.out_prefix)_reports
        mkdir $REPORTDIR
        mv *.html $REPORTDIR/
        mv *.Rmd $REPORTDIR/


  InlineJavascriptRequirement: {}

inputs:
  covariates:
    doc: |-
      Names of columns phenotype_file containing covariates, quoted and separated by spaces.
    type: string?
  out_prefix:
    doc: Prefix for files created by the software
    type: string?
    default: genesis-topmed
  outcome:
    doc: Name of column in Phenotype File containing outcome variable.
    type: string
  outcome_is_binary:
    doc: |-
      TRUE if outcome is a binary (case/control) variable; FALSE if outcome is a continuous variable.
    type:
      type: enum
      symbols:
      - 'TRUE'
      - 'FALSE'
    default: 'FALSE'
  pca_file:
    doc: RData file with PCA results created by PC-AiR.
    type: File?
    sbg:fileTypes: RDATA, Rdata
  phenotype_file:
    doc: RData file with AnnotatedDataFrame of phenotypes.
    type: File
    sbg:fileTypes: RDATA, Rdata
  relatedness_matrix:
    doc: RData or GDS file with a kinship matrix or GRM.
    type: File?
    sbg:fileTypes: GDS, RDATA, RData

outputs:
  null_model_files:
    doc: Null model files
    type: Directory
    outputBinding:
      glob: $(inputs.out_prefix)_datadir
  null_model_phenotype:
    doc: Phenotypes file
    type: File
    outputBinding:
      glob: phenotypes.RData
  reports:
    doc: HTML Reports generated by the tool + Rmd files
    type: Directory
    outputBinding:
      glob: $(inputs.out_prefix)_reports

baseCommand:
- sh
- script.sh
arguments: []
