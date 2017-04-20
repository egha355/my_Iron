!> \file
!> \author Vijay Rajagopal
!> \brief This module handles all reaction diffusion equation routines.
!>
!> \section LICENSE
!>
!> Version: MPL 1.1/GPL 2.0/LGPL 2.1
!>
!> The contents of this file are subject to the Mozilla Public License
!> Version 1.1 (the "License"); you may not use this file except in
!> compliance with the License. You may obtain a copy of the License at
!> http://www.mozilla.org/MPL/
!>
!> Software distributed under the License is distributed on an "AS IS"
!> basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
!> License for the specific language governing rights and limitations
!> under the License.
!>
!> The Original Code is OpenCMISS
!>
!> The Initial Developer of the Original Code is University of Auckland,
!> Auckland, New Zealand, the University of Oxford, Oxford, United
!> Kingdom and King's College, London, United Kingdom. Portions created
!> by the University of Auckland, the University of Oxford and King's
!> College, London are Copyright (C) 2007-2010 by the University of
!> Auckland, the University of Oxford and King's College, London.
!> All Rights Reserved.
!>
!> Contributor(s):
!>
!> Alternatively, the contents of this file may be used under the terms of
!> either the GNU General Public License Version 2 or later (the "GPL"), or
!> the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
!> in which case the provisions of the GPL or the LGPL are applicable instead
!> of those above. If you wish to allow use of your version of this file only
!> under the terms of either the GPL or the LGPL, and not to allow others to
!> use your version of this file under the terms of the MPL, indicate your
!> decision by deleting the provisions above and replace them with the notice
!> and other provisions required by the GPL or the LGPL. If you do not delete
!> the provisions above, a recipient may use your version of this file under
!> the terms of any one of the MPL, the GPL or the LGPL.
!>

!>This module handles all reaction diffusion equation routines.
MODULE REACTION_DIFFUSION_EQUATION_ROUTINES

  USE BASE_ROUTINES
  USE BASIS_ROUTINES
  USE BOUNDARY_CONDITIONS_ROUTINES
  USE COMP_ENVIRONMENT
  USE CONSTANTS
  USE CONTROL_LOOP_ROUTINES
  USE ControlLoopAccessRoutines
  USE DISTRIBUTED_MATRIX_VECTOR
  USE DOMAIN_MAPPINGS
  USE EquationsRoutines
  USE EQUATIONS_MAPPING_ROUTINES
  USE EQUATIONS_MATRICES_ROUTINES
  USE EQUATIONS_SET_CONSTANTS
  USE EquationsSetAccessRoutines
  USE FIELD_ROUTINES
  USE FieldAccessRoutines
  USE INPUT_OUTPUT
  USE ISO_VARYING_STRING
  USE KINDS
  USE MATRIX_VECTOR
#ifndef NOMPIMOD
  USE MPI
#endif
  USE PROBLEM_CONSTANTS
  USE STRINGS
  USE SOLVER_ROUTINES
  USE SolverAccessRoutines
  USE TIMER
  USE TYPES
  
  USE REACTION_DIFFUSION_IO_ROUTINES

#include "macros.h"  

  IMPLICIT NONE

  PRIVATE

#ifdef NOMPIMOD
#include "mpif.h"
#endif

  !Module parameters

  !Module types

  !Module variables

  !Interfaces

  PUBLIC ReactionDiffusion_EquationsSetSetup

  PUBLIC ReactionDiffusion_EquationsSetSolutionMethodSet
  
  PUBLIC ReactionDiffusion_EquationsSetSpecificationSet

  PUBLIC ReactionDiffusion_FiniteElementCalculate
  
  PUBLIC REACTION_DIFFUSION_PRE_SOLVE
  
  PUBLIC REACTION_DIFFUSION_EQUATION_PROBLEM_SETUP

  PUBLIC ReactionDiffusion_ProblemSpecificationSet

  PUBLIC REACTION_DIFFUSION_POST_SOLVE

  PUBLIC REACTION_DIFFUSION_CONTROL_LOOP_POST_LOOP


CONTAINS

  !
  !================================================================================================================================
  !

  !>Sets up the reaction diffusion equation type of a classical equations set class.
  SUBROUTINE ReactionDiffusion_EquationsSetSetup(EQUATIONS_SET,EQUATIONS_SET_SETUP,ERR,ERROR,*)

    !Argument variables
    TYPE(EQUATIONS_SET_TYPE), POINTER :: EQUATIONS_SET !<A pointer to the equations set to setup a bioelectric domain equation on.
    TYPE(EQUATIONS_SET_SETUP_TYPE), INTENT(INOUT) :: EQUATIONS_SET_SETUP !<The equations set setup information
    INTEGER(INTG), INTENT(OUT) :: ERR !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: ERROR !<The error string
    !Local Variables
    INTEGER(INTG) :: component_idx,DIMENSION_MULTIPLIER,GEOMETRIC_COMPONENT_NUMBER,GEOMETRIC_SCALING_TYPE, &
      & NUMBER_OF_DIMENSIONS,NUMBER_OF_MATERIALS_COMPONENTS,GEOMETRIC_MESH_COMPONENT
    TYPE(DECOMPOSITION_TYPE), POINTER :: GEOMETRIC_DECOMPOSITION
    TYPE(EquationsType), POINTER :: EQUATIONS
    TYPE(EQUATIONS_MAPPING_TYPE), POINTER :: EQUATIONS_MAPPING
    TYPE(EQUATIONS_SET_MATERIALS_TYPE), POINTER :: EQUATIONS_MATERIALS
    TYPE(EQUATIONS_MATRICES_TYPE), POINTER :: EQUATIONS_MATRICES
    TYPE(VARYING_STRING) :: LOCAL_ERROR
    
    ENTERS("ReactionDiffusion_EquationsSetSetup",ERR,ERROR,*999)

    NULLIFY(EQUATIONS)
    NULLIFY(EQUATIONS_MAPPING)
    NULLIFY(EQUATIONS_MATRICES)
    NULLIFY(GEOMETRIC_DECOMPOSITION)

    IF(ASSOCIATED(EQUATIONS_SET)) THEN
      IF(.NOT.ALLOCATED(EQUATIONS_SET%SPECIFICATION)) THEN
        CALL FlagError("Equations set specification is not allocated.",err,error,*999)
      ELSE IF(SIZE(EQUATIONS_SET%SPECIFICATION,1)/=3) THEN
        CALL FlagError("Equations set specification must have three entries for a reaction-diffusion type equations set.", &
          & err,error,*999)
      END IF
      SELECT CASE(EQUATIONS_SET_SETUP%SETUP_TYPE)
      CASE(EQUATIONS_SET_SETUP_INITIAL_TYPE)
        SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
        CASE(EQUATIONS_SET_SETUP_START_ACTION)
          CALL ReactionDiffusion_EquationsSetSolutionMethodSet(EQUATIONS_SET, &
           & EQUATIONS_SET_FEM_SOLUTION_METHOD,ERR,ERROR,*999)
        CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
!!Todo: CHECK VALID SETUP
        CASE DEFAULT
          LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
            & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
            & " is invalid for a reaction diffusion domain equation."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      CASE(EQUATIONS_SET_SETUP_GEOMETRY_TYPE)
        !\todo Check geometric dimension
      CASE(EQUATIONS_SET_SETUP_DEPENDENT_TYPE)
        SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
        CASE(EQUATIONS_SET_SETUP_START_ACTION)
          SELECT CASE(EQUATIONS_SET%SPECIFICATION(3))
          CASE(EQUATIONS_SET_CELLML_REAC_SPLIT_REAC_DIFF_SUBTYPE, &
           & EQUATIONS_SET_CONSTANT_REAC_DIFF_SUBTYPE)
            IF(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD_AUTO_CREATED) THEN
              !Create the auto created dependent field
              CALL FIELD_CREATE_START(EQUATIONS_SET_SETUP%FIELD_USER_NUMBER,EQUATIONS_SET%REGION,EQUATIONS_SET%DEPENDENT% &
                & DEPENDENT_FIELD,ERR,ERROR,*999)
              CALL FIELD_LABEL_SET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,"Dependent Field",ERR,ERROR,*999)
              CALL FIELD_TYPE_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_GENERAL_TYPE,ERR,ERROR,*999)
              CALL FIELD_DEPENDENT_TYPE_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_DEPENDENT_TYPE,ERR,ERROR,*999)
              CALL FIELD_MESH_DECOMPOSITION_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_DECOMPOSITION,ERR,ERROR,*999)
              CALL FIELD_MESH_DECOMPOSITION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,GEOMETRIC_DECOMPOSITION, &
                & ERR,ERROR,*999)
              CALL FIELD_GEOMETRIC_FIELD_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,EQUATIONS_SET%GEOMETRY% &
                & GEOMETRIC_FIELD,ERR,ERROR,*999)
              CALL FIELD_NUMBER_OF_VARIABLES_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,2,ERR,ERROR,*999)
              CALL FIELD_VARIABLE_TYPES_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,[FIELD_U_VARIABLE_TYPE, &
                & FIELD_DELUDELN_VARIABLE_TYPE],ERR,ERROR,*999)
              !CALL FIELD_VARIABLE_LABEL_SET
              CALL FIELD_DIMENSION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                & FIELD_SCALAR_DIMENSION_TYPE,ERR,ERROR,*999)
              CALL FIELD_DIMENSION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_DELUDELN_VARIABLE_TYPE, &
                & FIELD_SCALAR_DIMENSION_TYPE,ERR,ERROR,*999)
              CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                & FIELD_DP_TYPE,ERR,ERROR,*999)
              CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_DELUDELN_VARIABLE_TYPE, &
                & FIELD_DP_TYPE,ERR,ERROR,*999)
              CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,1, &
                & ERR,ERROR,*999)
              CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_DELUDELN_VARIABLE_TYPE,1, &
                & ERR,ERROR,*999)
              !Default to the geometric interpolation setup
              CALL FIELD_COMPONENT_MESH_COMPONENT_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,1, &
                & GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
              CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,1, &
                & GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
              CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_DELUDELN_VARIABLE_TYPE,1, &
                & GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
              SELECT CASE(EQUATIONS_SET%SOLUTION_METHOD)
              CASE(EQUATIONS_SET_FEM_SOLUTION_METHOD)
                CALL FIELD_COMPONENT_INTERPOLATION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                  & FIELD_U_VARIABLE_TYPE,1,FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                CALL FIELD_COMPONENT_INTERPOLATION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                  & FIELD_DELUDELN_VARIABLE_TYPE,1,FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                !Default the scaling to the geometric field scaling
                CALL FIELD_SCALING_TYPE_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_SCALING_TYPE,ERR,ERROR,*999)
                CALL FIELD_SCALING_TYPE_SET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,GEOMETRIC_SCALING_TYPE,ERR,ERROR,*999)
              CASE(EQUATIONS_SET_BEM_SOLUTION_METHOD)
                CALL FlagError("Not implemented.",ERR,ERROR,*999)
              CASE(EQUATIONS_SET_FD_SOLUTION_METHOD)
                CALL FlagError("Not implemented.",ERR,ERROR,*999)
              CASE(EQUATIONS_SET_FV_SOLUTION_METHOD)
                CALL FlagError("Not implemented.",ERR,ERROR,*999)
              CASE(EQUATIONS_SET_GFEM_SOLUTION_METHOD)
                CALL FlagError("Not implemented.",ERR,ERROR,*999)
              CASE(EQUATIONS_SET_GFV_SOLUTION_METHOD)
                CALL FlagError("Not implemented.",ERR,ERROR,*999)
              CASE DEFAULT
                LOCAL_ERROR="The solution method of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SOLUTION_METHOD,"*",ERR,ERROR))// &
                  & " is invalid."
                CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            ELSE
              !Check the user specified field
              CALL FIELD_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_GENERAL_TYPE,ERR,ERROR,*999)
              CALL FIELD_DEPENDENT_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_DEPENDENT_TYPE,ERR,ERROR,*999)
              CALL FIELD_NUMBER_OF_VARIABLES_CHECK(EQUATIONS_SET_SETUP%FIELD,2,ERR,ERROR,*999)
              CALL FIELD_VARIABLE_TYPES_CHECK(EQUATIONS_SET_SETUP%FIELD,[FIELD_U_VARIABLE_TYPE,FIELD_DELUDELN_VARIABLE_TYPE], &
                & ERR,ERROR,*999)
              CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,FIELD_SCALAR_DIMENSION_TYPE,ERR,ERROR,*999)
              CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_DELUDELN_VARIABLE_TYPE,FIELD_SCALAR_DIMENSION_TYPE, &
                & ERR,ERROR,*999)
              CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,FIELD_DP_TYPE,ERR,ERROR,*999)
              CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_DELUDELN_VARIABLE_TYPE,FIELD_DP_TYPE,ERR,ERROR,*999)
              CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,1,ERR,ERROR,*999)
              CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_DELUDELN_VARIABLE_TYPE,1,ERR,ERROR,*999)
              SELECT CASE(EQUATIONS_SET%SOLUTION_METHOD)
              CASE(EQUATIONS_SET_FEM_SOLUTION_METHOD)
                CALL FIELD_COMPONENT_INTERPOLATION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,1, &
                  & FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                CALL FIELD_COMPONENT_INTERPOLATION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_DELUDELN_VARIABLE_TYPE,1, &
                  & FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
              CASE(EQUATIONS_SET_BEM_SOLUTION_METHOD)
                CALL FlagError("Not implemented.",ERR,ERROR,*999)
              CASE(EQUATIONS_SET_FD_SOLUTION_METHOD)
                CALL FlagError("Not implemented.",ERR,ERROR,*999)
              CASE(EQUATIONS_SET_FV_SOLUTION_METHOD)
                CALL FlagError("Not implemented.",ERR,ERROR,*999)
              CASE(EQUATIONS_SET_GFEM_SOLUTION_METHOD)
                CALL FlagError("Not implemented.",ERR,ERROR,*999)
              CASE(EQUATIONS_SET_GFV_SOLUTION_METHOD)
                CALL FlagError("Not implemented.",ERR,ERROR,*999)
              CASE DEFAULT
                LOCAL_ERROR="The solution method of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SOLUTION_METHOD,"*",ERR,ERROR))// &
                  & " is invalid."
                CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            ENDIF
          CASE(EQUATIONS_SET_CELLML_REAC_NO_SPLIT_REAC_DIFF_SUBTYPE)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The equation set subtype of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SPECIFICATION(3),"*",ERR,ERROR))// &
              & " is invalid for a reaction diffusion equation set class."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
          IF(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD_AUTO_CREATED) THEN
            CALL FIELD_CREATE_FINISH(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,ERR,ERROR,*999)
          ENDIF
        CASE DEFAULT
          LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
            & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
            & " is invalid for a reaction diffusion equation"
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      CASE(EQUATIONS_SET_SETUP_MATERIALS_TYPE)
        SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
        CASE(EQUATIONS_SET_SETUP_START_ACTION)
          IF(EQUATIONS_SET%DEPENDENT%DEPENDENT_FINISHED) THEN
            EQUATIONS_MATERIALS=>EQUATIONS_SET%MATERIALS
            IF(ASSOCIATED(EQUATIONS_MATERIALS)) THEN
              IF(EQUATIONS_MATERIALS%MATERIALS_FIELD_AUTO_CREATED) THEN
                !Create the auto created materials field
                CALL FIELD_CREATE_START(EQUATIONS_SET_SETUP%FIELD_USER_NUMBER,EQUATIONS_SET%REGION,EQUATIONS_MATERIALS% &
                  & MATERIALS_FIELD,ERR,ERROR,*999)
                CALL FIELD_TYPE_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_MATERIAL_TYPE,ERR,ERROR,*999)
                CALL FIELD_DEPENDENT_TYPE_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_INDEPENDENT_TYPE,ERR,ERROR,*999)
                CALL FIELD_MESH_DECOMPOSITION_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_DECOMPOSITION,ERR,ERROR,*999)
                CALL FIELD_MESH_DECOMPOSITION_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,GEOMETRIC_DECOMPOSITION, &
                  & ERR,ERROR,*999)
                CALL FIELD_GEOMETRIC_FIELD_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,EQUATIONS_SET%GEOMETRY% &
                  & GEOMETRIC_FIELD,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_VARIABLES_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,1,ERR,ERROR,*999)
                CALL FIELD_VARIABLE_TYPES_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,[FIELD_U_VARIABLE_TYPE], &
                  & ERR,ERROR,*999)
                CALL FIELD_DIMENSION_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & NUMBER_OF_DIMENSIONS,ERR,ERROR,*999)
                IF(EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_CELLML_REAC_SPLIT_REAC_DIFF_SUBTYPE) THEN
                  !Reaction Diffusion. Materials field components are 1 diffusion coeff for each dimension
                  !plus one for the storage coefficient in alpha(delC/delt) = Div(-kgradC)+cellmlRC
                  NUMBER_OF_MATERIALS_COMPONENTS=NUMBER_OF_DIMENSIONS+1
                  DIMENSION_MULTIPLIER=1
                ELSEIF(EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_CONSTANT_REAC_DIFF_SUBTYPE) THEN
                  !Constant reaction + diffusion. Materials field has 1 diffuse coeff for each dimension
                  !plus one for the storage coefficient om  alpha(delC/delt) = Div(-kgradC)+const(x)_source
                  NUMBER_OF_MATERIALS_COMPONENTS=NUMBER_OF_DIMENSIONS+1
                  DIMENSION_MULTIPLIER=1
                ENDIF
                !Set the number of materials components
                CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & NUMBER_OF_MATERIALS_COMPONENTS,ERR,ERROR,*999)
                !Default the first three materials components for diffusivity param to the first component geometric interpolation with const interpolation
                DO component_idx=1,NUMBER_OF_DIMENSIONS
                  CALL FIELD_COMPONENT_MESH_COMPONENT_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                    & 1,GEOMETRIC_COMPONENT_NUMBER,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                    & component_idx,GEOMETRIC_COMPONENT_NUMBER,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_INTERPOLATION_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                    & component_idx,FIELD_CONSTANT_INTERPOLATION,ERR,ERROR,*999)
                ENDDO !components_idx
                !Default the storage co-efficient to the first geometric interpolation setup with constant interpolation
                IF(EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_CELLML_REAC_SPLIT_REAC_DIFF_SUBTYPE) THEN
                  component_idx=NUMBER_OF_MATERIALS_COMPONENTS
                  CALL FIELD_COMPONENT_MESH_COMPONENT_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                    & 1,GEOMETRIC_COMPONENT_NUMBER,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                    & component_idx,GEOMETRIC_COMPONENT_NUMBER,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_INTERPOLATION_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                    & component_idx,FIELD_CONSTANT_INTERPOLATION,ERR,ERROR,*999)
                ENDIF
                !Default the field scaling to that of the geometric field
                CALL FIELD_SCALING_TYPE_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_SCALING_TYPE,ERR,ERROR,*999)
                CALL FIELD_SCALING_TYPE_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD,GEOMETRIC_SCALING_TYPE,ERR,ERROR,*999)
              ELSE
                !Check the user specified field
                CALL FIELD_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_MATERIAL_TYPE,ERR,ERROR,*999)
                CALL FIELD_DEPENDENT_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_INDEPENDENT_TYPE,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_VARIABLES_CHECK(EQUATIONS_SET_SETUP%FIELD,1,ERR,ERROR,*999)
                CALL FIELD_VARIABLE_TYPES_CHECK(EQUATIONS_SET_SETUP%FIELD,[FIELD_U_VARIABLE_TYPE],ERR,ERROR,*999)
                CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VECTOR_DIMENSION_TYPE, &
                  & ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & NUMBER_OF_DIMENSIONS,ERR,ERROR,*999)
                IF(EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_CELLML_REAC_SPLIT_REAC_DIFF_SUBTYPE .OR. &
                 & EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_CONSTANT_REAC_DIFF_SUBTYPE) THEN
                  !Reaction Diffusion with cellml. Materials field components are 1 for storage coeff plus one for each dimension i.e., k
                  CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,NUMBER_OF_DIMENSIONS+1, &
                    & ERR,ERROR,*999)
                ENDIF
              ENDIF
            ELSE
              CALL FlagError("Equations set materials is not associated.",ERR,ERROR,*999)
            ENDIF
          ELSE
            CALL FlagError("Equations set dependent field has not been finished.",ERR,ERROR,*999)
          ENDIF
        CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
          EQUATIONS_MATERIALS=>EQUATIONS_SET%MATERIALS
          IF(ASSOCIATED(EQUATIONS_MATERIALS)) THEN
            IF(EQUATIONS_MATERIALS%MATERIALS_FIELD_AUTO_CREATED) THEN
              !Finish creating the materials field
              CALL FIELD_CREATE_FINISH(EQUATIONS_MATERIALS%MATERIALS_FIELD,ERR,ERROR,*999)
              !Set the default values for the materials field
              CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                & NUMBER_OF_DIMENSIONS,ERR,ERROR,*999)
              IF(EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_CELLML_REAC_SPLIT_REAC_DIFF_SUBTYPE .OR. &
               & EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_CONSTANT_REAC_DIFF_SUBTYPE) THEN
                !Reaction Diffusion with cellml. Materials field components are 1 plus one for each dimension i.e.,storage coeff, and k.
                NUMBER_OF_MATERIALS_COMPONENTS=NUMBER_OF_DIMENSIONS+1
                DIMENSION_MULTIPLIER=1
              ENDIF
              !set the diffusion coefficients to be 1.0
              DO component_idx=1,NUMBER_OF_DIMENSIONS
                CALL FIELD_COMPONENT_VALUES_INITIALISE(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & FIELD_VALUES_SET_TYPE,component_idx,1.0_DP,ERR,ERROR,*999)
              ENDDO !component_idx
               !Now set storage-coefficient
              component_idx=NUMBER_OF_DIMENSIONS+1
              CALL FIELD_COMPONENT_VALUES_INITIALISE(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                & FIELD_VALUES_SET_TYPE,component_idx,1.0_DP,ERR,ERROR,*999)
            ENDIF
          ELSE
            CALL FlagError("Equations set materials is not associated.",ERR,ERROR,*999)
          ENDIF
        CASE DEFAULT
          LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
            & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
            & " is invalid for a reaction diffusion equation."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      CASE(EQUATIONS_SET_SETUP_SOURCE_TYPE)
        SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
        CASE(EQUATIONS_SET_SETUP_START_ACTION)
          IF(ASSOCIATED(EQUATIONS_SET%MATERIALS)) THEN
            IF(EQUATIONS_SET%MATERIALS%MATERIALS_FINISHED) THEN
              IF(ASSOCIATED(EQUATIONS_SET%SOURCE)) THEN
                IF(EQUATIONS_SET%SOURCE%SOURCE_FIELD_AUTO_CREATED) THEN
                  !Create the auto created source field
                  !Start field creation with name 'SOURCE_FIELD'
                  CALL FIELD_CREATE_START(EQUATIONS_SET_SETUP%FIELD_USER_NUMBER,EQUATIONS_SET%REGION, &
                    & EQUATIONS_SET%SOURCE%SOURCE_FIELD,ERR,ERROR,*999)
                  !Create a general field
                  CALL FIELD_TYPE_SET_AND_LOCK(EQUATIONS_SET%SOURCE%SOURCE_FIELD,FIELD_GENERAL_TYPE,ERR,ERROR,*999)
                  !Label the field
                  CALL FIELD_LABEL_SET_AND_LOCK(EQUATIONS_SET%SOURCE%SOURCE_FIELD,"Source Field",ERR,ERROR,*999)
                  !Set the dependent type
                  CALL FIELD_DEPENDENT_TYPE_SET_AND_LOCK(EQUATIONS_SET%SOURCE%SOURCE_FIELD,FIELD_INDEPENDENT_TYPE,ERR,ERROR,*999)
                  !Set the field decomposition to be that of the geometric decomposition
                  CALL FIELD_MESH_DECOMPOSITION_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_DECOMPOSITION,ERR,ERROR,*999)
                  CALL FIELD_MESH_DECOMPOSITION_SET_AND_LOCK(EQUATIONS_SET%SOURCE%SOURCE_FIELD,GEOMETRIC_DECOMPOSITION, &
                    & ERR,ERROR,*999)
                  !Set the geometric field
                  CALL FIELD_GEOMETRIC_FIELD_SET_AND_LOCK(EQUATIONS_SET%SOURCE%SOURCE_FIELD,EQUATIONS_SET% & 
                    & GEOMETRY%GEOMETRIC_FIELD,ERR,ERROR,*999)
                  !Set the field variables.
                  CALL FIELD_NUMBER_OF_VARIABLES_SET_AND_LOCK(EQUATIONS_SET%SOURCE%SOURCE_FIELD,1,ERR,ERROR,*999)
                  CALL FIELD_VARIABLE_TYPES_SET_AND_LOCK(EQUATIONS_SET%SOURCE%SOURCE_FIELD,[FIELD_U_VARIABLE_TYPE],ERR,ERROR,*999)
                  !Set the dimension
                  CALL FIELD_DIMENSION_SET_AND_LOCK(EQUATIONS_SET%SOURCE%SOURCE_FIELD,FIELD_U_VARIABLE_TYPE, &
                    & FIELD_SCALAR_DIMENSION_TYPE,ERR,ERROR,*999)
                  !Set the data type
                  CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_SET%SOURCE%SOURCE_FIELD,FIELD_U_VARIABLE_TYPE, &
                    & FIELD_DP_TYPE,ERR,ERROR,*999)
                  !Set the number of components to one
                  CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_SET%SOURCE%SOURCE_FIELD,FIELD_U_VARIABLE_TYPE,1, &
                    & ERR,ERROR,*999)
                  !Get the geometric mesh component
                  CALL FIELD_COMPONENT_MESH_COMPONENT_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, & 
                    & 1,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                  !Default to the geometric interpolation setup
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_SET%SOURCE%SOURCE_FIELD,FIELD_U_VARIABLE_TYPE,1, &
                    & GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)            
                  !Specify the interpolation to be same as geometric interpolation
                  SELECT CASE(EQUATIONS_SET%SOLUTION_METHOD)
                  CASE(EQUATIONS_SET_FEM_SOLUTION_METHOD)
                    CALL FIELD_COMPONENT_INTERPOLATION_SET_AND_LOCK(EQUATIONS_SET%SOURCE%SOURCE_FIELD,FIELD_U_VARIABLE_TYPE,1, &
                      & FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                  CASE(EQUATIONS_SET_BEM_SOLUTION_METHOD)
                    CALL FlagError("Not implemented.",ERR,ERROR,*999)
                  CASE(EQUATIONS_SET_FD_SOLUTION_METHOD)
                    CALL FlagError("Not implemented.",ERR,ERROR,*999)
                  CASE(EQUATIONS_SET_FV_SOLUTION_METHOD)
                    CALL FlagError("Not implemented.",ERR,ERROR,*999)
                  CASE(EQUATIONS_SET_GFEM_SOLUTION_METHOD)
                    CALL FlagError("Not implemented.",ERR,ERROR,*999)
                  CASE(EQUATIONS_SET_GFV_SOLUTION_METHOD)
                    CALL FlagError("Not implemented.",ERR,ERROR,*999)
                  CASE DEFAULT
                    LOCAL_ERROR="The solution method of " &
                      & //TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SOLUTION_METHOD,"*",ERR,ERROR))// " is invalid."
                    CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                  END SELECT
                  !Set the scaling to be the same as the geometric field
                  CALL FIELD_SCALING_TYPE_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_SCALING_TYPE, &
                    & ERR,ERROR,*999)
                  CALL FIELD_SCALING_TYPE_SET(EQUATIONS_SET%SOURCE%SOURCE_FIELD,GEOMETRIC_SCALING_TYPE, &
                    & ERR,ERROR,*999)
                ELSE
                  !Check the user specified field
                  CALL FIELD_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_GENERAL_TYPE,ERR,ERROR,*999)
                  CALL FIELD_DEPENDENT_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_INDEPENDENT_TYPE,ERR,ERROR,*999)
                  CALL FIELD_NUMBER_OF_VARIABLES_CHECK(EQUATIONS_SET_SETUP%FIELD,1,ERR,ERROR,*999)
                  CALL FIELD_VARIABLE_TYPES_CHECK(EQUATIONS_SET_SETUP%FIELD,[FIELD_U_VARIABLE_TYPE],ERR,ERROR,*999)
                  CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,FIELD_SCALAR_DIMENSION_TYPE, &
                    & ERR,ERROR,*999)
                  CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,FIELD_DP_TYPE,ERR,ERROR,*999)
                  CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,1,ERR,ERROR,*999)
                  
                  SELECT CASE(EQUATIONS_SET%SOLUTION_METHOD)
                  CASE(EQUATIONS_SET_FEM_SOLUTION_METHOD)
                    CALL FIELD_COMPONENT_INTERPOLATION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,1, &
                      & FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                  CASE(EQUATIONS_SET_BEM_SOLUTION_METHOD)
                    CALL FlagError("Not implemented.",ERR,ERROR,*999)
                  CASE(EQUATIONS_SET_FD_SOLUTION_METHOD)
                    CALL FlagError("Not implemented.",ERR,ERROR,*999)
                  CASE(EQUATIONS_SET_FV_SOLUTION_METHOD)
                    CALL FlagError("Not implemented.",ERR,ERROR,*999)
                  CASE(EQUATIONS_SET_GFEM_SOLUTION_METHOD)
                    CALL FlagError("Not implemented.",ERR,ERROR,*999)
                  CASE(EQUATIONS_SET_GFV_SOLUTION_METHOD)
                    CALL FlagError("Not implemented.",ERR,ERROR,*999)
                  CASE DEFAULT
                    LOCAL_ERROR="The solution method of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SOLUTION_METHOD, &
                      &"*",ERR,ERROR))//" is invalid."
                    CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                  END SELECT
                  
                ENDIF
              ELSE
                CALL FlagError("Equations set source is not associated.",ERR,ERROR,*999)
              ENDIF
            ELSE
              CALL FlagError("Equations set materials field has not been finished.",ERR,ERROR,*999)
            ENDIF
          ELSE
            CALL FlagError("Equations set materials is not associated.",ERR,ERROR,*999)
          ENDIF
        CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
          IF(EQUATIONS_SET%SOURCE%SOURCE_FIELD_AUTO_CREATED) THEN
            CALL FIELD_CREATE_FINISH(EQUATIONS_SET%SOURCE%SOURCE_FIELD,ERR,ERROR,*999)
          ENDIF
        CASE DEFAULT
          LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
            & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
            & " is invalid for a reaction diffusion equation."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      CASE(EQUATIONS_SET_SETUP_ANALYTIC_TYPE)
        SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
        CASE(EQUATIONS_SET_SETUP_START_ACTION)
          CALL FlagError("Not implemented.",ERR,ERROR,*999)
        CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
          CALL FlagError("Not implemented.",ERR,ERROR,*999)
        CASE DEFAULT
          LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
            & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
            & " is invalid for a reaction diffusion equation."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      CASE(EQUATIONS_SET_SETUP_EQUATIONS_TYPE)
        SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
        CASE(EQUATIONS_SET_SETUP_START_ACTION)
          IF(ASSOCIATED(EQUATIONS_SET%SOURCE)) THEN
            IF(EQUATIONS_SET%SOURCE%SOURCE_FINISHED) THEN
              !Create the equations
              CALL Equations_CreateStart(EQUATIONS_SET,EQUATIONS,ERR,ERROR,*999)
              SELECT CASE(EQUATIONS_SET%SPECIFICATION(3))
              CASE(EQUATIONS_SET_CELLML_REAC_SPLIT_REAC_DIFF_SUBTYPE)
                CALL Equations_LinearityTypeSet(EQUATIONS,EQUATIONS_LINEAR,ERR,ERROR,*999)
              CASE(EQUATIONS_SET_CONSTANT_REAC_DIFF_SUBTYPE)
                CALL Equations_LinearityTypeSet(EQUATIONS,EQUATIONS_LINEAR,ERR,ERROR,*999)
              CASE(EQUATIONS_SET_CELLML_REAC_NO_SPLIT_REAC_DIFF_SUBTYPE)
                CALL Equations_LinearityTypeSet(EQUATIONS,EQUATIONS_NONLINEAR,ERR,ERROR,*999)
              CASE DEFAULT
                LOCAL_ERROR="The equations matrices linearity set up of "// &
                  & TRIM(NUMBER_TO_VSTRING(EQUATIONS%sparsityType,"*",ERR,ERROR))//" is invalid."
                CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
              CALL Equations_TimeDependenceTypeSet(EQUATIONS,EQUATIONS_FIRST_ORDER_DYNAMIC,ERR,ERROR,*999)
            ELSE
              CALL FlagError("Equations set source field has not been finished.",ERR,ERROR,*999)
            ENDIF
          ELSE
            CALL FlagError("Equations set source is not associated.",ERR,ERROR,*999)
          ENDIF
        CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
          SELECT CASE(EQUATIONS_SET%SOLUTION_METHOD)
          CASE(EQUATIONS_SET_FEM_SOLUTION_METHOD)
            !Finish the creation of the equations
            CALL EquationsSet_EquationsGet(EQUATIONS_SET,EQUATIONS,ERR,ERROR,*999)
            CALL Equations_CreateFinish(EQUATIONS,ERR,ERROR,*999)
            !Create the equations mapping.
            CALL EQUATIONS_MAPPING_CREATE_START(EQUATIONS,EQUATIONS_MAPPING,ERR,ERROR,*999)
            CALL EQUATIONS_MAPPING_DYNAMIC_MATRICES_SET(EQUATIONS_MAPPING,.TRUE.,.TRUE.,ERR,ERROR,*999)
            CALL EQUATIONS_MAPPING_DYNAMIC_VARIABLE_TYPE_SET(EQUATIONS_MAPPING,FIELD_U_VARIABLE_TYPE,ERR,ERROR,*999)
            CALL EQUATIONS_MAPPING_RHS_VARIABLE_TYPE_SET(EQUATIONS_MAPPING,FIELD_DELUDELN_VARIABLE_TYPE,ERR,ERROR,*999)

            CALL EQUATIONS_MAPPING_SOURCE_VARIABLE_TYPE_SET(EQUATIONS_MAPPING,FIELD_U_VARIABLE_TYPE,ERR,ERROR,*999)
            CALL EQUATIONS_MAPPING_CREATE_FINISH(EQUATIONS_MAPPING,ERR,ERROR,*999)
            !Create the equations matrices
            CALL EQUATIONS_MATRICES_CREATE_START(EQUATIONS,EQUATIONS_MATRICES,ERR,ERROR,*999)
            !Set up matrix storage and structure
            IF(EQUATIONS%lumpingType==EQUATIONS_LUMPED_MATRICES) THEN
              !Set up lumping
              CALL EQUATIONS_MATRICES_DYNAMIC_LUMPING_TYPE_SET(EQUATIONS_MATRICES, &
                & [EQUATIONS_MATRIX_UNLUMPED,EQUATIONS_MATRIX_LUMPED],ERR,ERROR,*999)
              CALL EQUATIONS_MATRICES_DYNAMIC_STORAGE_TYPE_SET(EQUATIONS_MATRICES, &
                & [DISTRIBUTED_MATRIX_COMPRESSED_ROW_STORAGE_TYPE,DISTRIBUTED_MATRIX_DIAGONAL_STORAGE_TYPE], &
                & ERR,ERROR,*999)
              CALL EquationsMatrices_DynamicStructureTypeSet(EQUATIONS_MATRICES, &
                [EQUATIONS_MATRIX_FEM_STRUCTURE,EQUATIONS_MATRIX_DIAGONAL_STRUCTURE],ERR,ERROR,*999)
            ELSE
              SELECT CASE(EQUATIONS%sparsityType)
              CASE(EQUATIONS_MATRICES_FULL_MATRICES) 
                CALL EQUATIONS_MATRICES_DYNAMIC_STORAGE_TYPE_SET(EQUATIONS_MATRICES, &
                  & [DISTRIBUTED_MATRIX_BLOCK_STORAGE_TYPE,DISTRIBUTED_MATRIX_BLOCK_STORAGE_TYPE], &
                  & ERR,ERROR,*999)
              CASE(EQUATIONS_MATRICES_SPARSE_MATRICES)
                CALL EQUATIONS_MATRICES_DYNAMIC_STORAGE_TYPE_SET(EQUATIONS_MATRICES, &
                  & [DISTRIBUTED_MATRIX_COMPRESSED_ROW_STORAGE_TYPE,DISTRIBUTED_MATRIX_COMPRESSED_ROW_STORAGE_TYPE], &
                  & ERR,ERROR,*999)
                CALL EquationsMatrices_DynamicStructureTypeSet(EQUATIONS_MATRICES, &
                  [EQUATIONS_MATRIX_FEM_STRUCTURE,EQUATIONS_MATRIX_FEM_STRUCTURE],ERR,ERROR,*999)                  
              CASE DEFAULT
                LOCAL_ERROR="The equations matrices sparsity type of "// &
                  & TRIM(NUMBER_TO_VSTRING(EQUATIONS%sparsityType,"*",ERR,ERROR))//" is invalid."
                CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            ENDIF
            CALL EQUATIONS_MATRICES_CREATE_FINISH(EQUATIONS_MATRICES,ERR,ERROR,*999)
          CASE(EQUATIONS_SET_BEM_SOLUTION_METHOD)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(EQUATIONS_SET_FD_SOLUTION_METHOD)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(EQUATIONS_SET_FV_SOLUTION_METHOD)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(EQUATIONS_SET_GFEM_SOLUTION_METHOD)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(EQUATIONS_SET_GFV_SOLUTION_METHOD)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The solution method of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SOLUTION_METHOD,"*",ERR,ERROR))// &
              & " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE DEFAULT
          LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
            & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
            & " is invalid for a bioelectric domain equation."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      CASE DEFAULT
        LOCAL_ERROR="The setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
          & " is invalid for reaction diffusion equation."
        CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
      END SELECT
    ELSE
      CALL FlagError("Equations set is not associated.",ERR,ERROR,*999)
    ENDIF
    
    EXITS("ReactionDiffusion_EquationsSetSetup")
    RETURN
999 ERRORSEXITS("ReactionDiffusion_EquationsSetSetup",ERR,ERROR)
    RETURN 1
    
  END SUBROUTINE ReactionDiffusion_EquationsSetSetup

  !
  !================================================================================================================================
  !

  !>Sets/changes the solution method for a reaction diffusion equation type of a classical equations set class.
  SUBROUTINE ReactionDiffusion_EquationsSetSolutionMethodSet(EQUATIONS_SET,SOLUTION_METHOD,ERR,ERROR,*)

    !Argument variables
    TYPE(EQUATIONS_SET_TYPE), POINTER :: EQUATIONS_SET !<A pointer to the equations set to set the solution method for
    INTEGER(INTG), INTENT(IN) :: SOLUTION_METHOD !<The solution method to set
    INTEGER(INTG), INTENT(OUT) :: ERR !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: ERROR !<The error string
    !Local Variables
    TYPE(VARYING_STRING) :: LOCAL_ERROR
    
    ENTERS("ReactionDiffusion_EquationsSetSolutionMethodSet",ERR,ERROR,*999)
    
    IF(ASSOCIATED(EQUATIONS_SET)) THEN
      IF(.NOT.ALLOCATED(EQUATIONS_SET%SPECIFICATION)) THEN
        CALL FlagError("Equations set specification is not allocated.",err,error,*999)
      ELSE IF(SIZE(EQUATIONS_SET%SPECIFICATION,1)/=3) THEN
        CALL FlagError("Equations set specification must have three entries for a reaction-diffusion type equations set.", &
          & err,error,*999)
      END IF
      SELECT CASE(EQUATIONS_SET%SPECIFICATION(3))
      CASE(EQUATIONS_SET_CELLML_REAC_SPLIT_REAC_DIFF_SUBTYPE, &
         & EQUATIONS_SET_CELLML_REAC_NO_SPLIT_REAC_DIFF_SUBTYPE, &
         & EQUATIONS_SET_CONSTANT_REAC_DIFF_SUBTYPE)        
        SELECT CASE(SOLUTION_METHOD)
        CASE(EQUATIONS_SET_FEM_SOLUTION_METHOD)
          EQUATIONS_SET%SOLUTION_METHOD=EQUATIONS_SET_FEM_SOLUTION_METHOD
        CASE(EQUATIONS_SET_BEM_SOLUTION_METHOD)
          CALL FlagError("Not implemented.",ERR,ERROR,*999)
        CASE(EQUATIONS_SET_FD_SOLUTION_METHOD)
          CALL FlagError("Not implemented.",ERR,ERROR,*999)
        CASE(EQUATIONS_SET_FV_SOLUTION_METHOD)
          CALL FlagError("Not implemented.",ERR,ERROR,*999)
        CASE(EQUATIONS_SET_GFEM_SOLUTION_METHOD)
          CALL FlagError("Not implemented.",ERR,ERROR,*999)
        CASE(EQUATIONS_SET_GFV_SOLUTION_METHOD)
          CALL FlagError("Not implemented.",ERR,ERROR,*999)
        CASE DEFAULT
          LOCAL_ERROR="The specified solution method of "//TRIM(NUMBER_TO_VSTRING(SOLUTION_METHOD,"*",ERR,ERROR))//" is invalid."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      CASE DEFAULT
        LOCAL_ERROR="Equations set subtype of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SPECIFICATION(3),"*",ERR,ERROR))// &
          & " is not valid for a reaction diffusion equation type of classical equations set class."
        CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
      END SELECT

    ELSE
      CALL FlagError("Equations set is not associated.",ERR,ERROR,*999)
    ENDIF
       
    EXITS("ReactionDiffusion_EquationsSetSolutionMethodSet")
    RETURN
999 ERRORS("ReactionDiffusion_EquationsSetSolutionMethodSet",ERR,ERROR)
    EXITS("ReactionDiffusion_EquationsSetSolutionMethodSet")
    RETURN 1
    
  END SUBROUTINE ReactionDiffusion_EquationsSetSolutionMethodSet

  !
  !================================================================================================================================ 
  !

  !>Sets the equation specification for a reaction diffusion equation type of a classical equations set class.
  SUBROUTINE ReactionDiffusion_EquationsSetSpecificationSet(equationsSet,specification,err,error,*)

    !Argument variables
    TYPE(EQUATIONS_SET_TYPE), POINTER :: equationsSet !<A pointer to the equations set to set the specification for
    INTEGER(INTG), INTENT(IN) :: specification(:) !<The equations set specification to set
    INTEGER(INTG), INTENT(OUT) :: err !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: error !<The error string
    !Local Variables
    TYPE(VARYING_STRING) :: localError
    INTEGER(INTG) :: subtype

    ENTERS("ReactionDiffusion_EquationsSetSpecificationSet",err,error,*999)

    IF(ASSOCIATED(equationsSet)) THEN
      IF(SIZE(specification,1)>3) THEN
        CALL FlagError("Equations set specification must have 3 entries for a reaction-diffusion type equations set.", &
          & err,error,*999)
      END IF
      subtype=specification(3)
      SELECT CASE(subtype)
      CASE(EQUATIONS_SET_CELLML_REAC_SPLIT_REAC_DIFF_SUBTYPE)
        !ok
      CASE(EQUATIONS_SET_CELLML_REAC_NO_SPLIT_REAC_DIFF_SUBTYPE)
        CALL FlagError("Not implemented.",err,error,*999)
      CASE(EQUATIONS_SET_CONSTANT_REAC_DIFF_SUBTYPE)
        !ok
      CASE DEFAULT
        localError="The specified equations set subtype of "//TRIM(NumberToVstring(subtype,"*",err,error))// &
          & " is not valid for reaction diffusion equation type of a classical equations set class."
        CALL FlagError(localError,err,error,*999)
      END SELECT
      !Set full specification
      IF(ALLOCATED(equationsSet%specification)) THEN
        CALL FlagError("Equations set specification is already allocated.",err,error,*999)
      ELSE
        ALLOCATE(equationsSet%specification(3),stat=err)
        IF(err/=0) CALL FlagError("Could not allocate equations set specification.",err,error,*999)
      END IF
      equationsSet%specification(1:3)=[EQUATIONS_SET_CLASSICAL_FIELD_CLASS,EQUATIONS_SET_REACTION_DIFFUSION_EQUATION_TYPE,subtype]
    ELSE
      CALL FlagError("Equations set is not associated.",err,error,*999)
    END IF

    EXITS("ReactionDiffusion_EquationsSetSpecificationSet")
    RETURN
999 ERRORS("ReactionDiffusion_EquationsSetSpecificationSet",err,error)
    EXITS("ReactionDiffusion_EquationsSetSpecificationSet")
    RETURN 1
    
  END SUBROUTINE ReactionDiffusion_EquationsSetSpecificationSet

  !
  !================================================================================================================================
  !
  !>Calculates the element stiffness matrices and RHS for a reaction diffusion equation finite element equations set.
  SUBROUTINE ReactionDiffusion_FiniteElementCalculate(EQUATIONS_SET,ELEMENT_NUMBER,ERR,ERROR,*)

    !Argument variables
    TYPE(EQUATIONS_SET_TYPE), POINTER :: EQUATIONS_SET !<A pointer to the equations set to perform the finite element calculations on
    INTEGER(INTG), INTENT(IN) :: ELEMENT_NUMBER !<The element number to calculate
    INTEGER(INTG), INTENT(OUT) :: ERR !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: ERROR !<The error string
    !Local Variables
    INTEGER(INTG) FIELD_VAR_TYPE,mh,mhs,ms,ng,nh,nhs,ni,nj,ns,component_idx
    LOGICAL :: USE_FIBRES
    REAL(DP) :: DIFFUSIVITY(3,3),DPHIDX(3,64),RWG,SUM,STORAGE_COEFFICIENT,C_PARAM
    TYPE(BASIS_TYPE), POINTER :: DEPENDENT_BASIS,GEOMETRIC_BASIS,FIBRE_BASIS
    TYPE(EquationsType), POINTER :: EQUATIONS
    TYPE(EQUATIONS_MAPPING_TYPE), POINTER :: EQUATIONS_MAPPING
    TYPE(EQUATIONS_MAPPING_DYNAMIC_TYPE), POINTER :: DYNAMIC_MAPPING
    TYPE(EQUATIONS_MATRICES_TYPE), POINTER :: EQUATIONS_MATRICES
    TYPE(EQUATIONS_MATRICES_DYNAMIC_TYPE), POINTER :: DYNAMIC_MATRICES
    TYPE(EQUATIONS_MATRICES_RHS_TYPE), POINTER :: RHS_VECTOR
    TYPE(EQUATIONS_MATRICES_SOURCE_TYPE), POINTER :: SOURCE_VECTOR
    TYPE(EQUATIONS_MATRIX_TYPE), POINTER :: DAMPING_MATRIX,STIFFNESS_MATRIX
    TYPE(FIELD_TYPE), POINTER :: DEPENDENT_FIELD,GEOMETRIC_FIELD,FIBRE_FIELD,MATERIALS_FIELD,SOURCE_FIELD
    TYPE(FIELD_VARIABLE_TYPE), POINTER :: FIELD_VARIABLE,GEOMETRIC_VARIABLE
    TYPE(QUADRATURE_SCHEME_TYPE), POINTER :: QUADRATURE_SCHEME
    
    ENTERS("ReactionDiffusion_FiniteElementCalculate",ERR,ERROR,*999)

    IF(ASSOCIATED(EQUATIONS_SET)) THEN
      IF(.NOT.ALLOCATED(EQUATIONS_SET%SPECIFICATION)) THEN
        CALL FlagError("Equations set specification is not allocated.",err,error,*999)
      ELSE IF(SIZE(EQUATIONS_SET%SPECIFICATION,1)/=3) THEN
        CALL FlagError("Equations set specification must have three entries for a reaction-diffusion type equations set.", &
          & err,error,*999)
      END IF
      EQUATIONS=>EQUATIONS_SET%EQUATIONS
      IF(ASSOCIATED(EQUATIONS)) THEN
        
        DEPENDENT_FIELD=>EQUATIONS%INTERPOLATION%DEPENDENT_FIELD
        GEOMETRIC_FIELD=>EQUATIONS%INTERPOLATION%GEOMETRIC_FIELD
        MATERIALS_FIELD=>EQUATIONS%INTERPOLATION%MATERIALS_FIELD
        IF(EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_CELLML_REAC_NO_SPLIT_REAC_DIFF_SUBTYPE .OR. &
            & EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_CONSTANT_REAC_DIFF_SUBTYPE) THEN
           SOURCE_FIELD=>EQUATIONS%INTERPOLATION%SOURCE_FIELD
        ENDIF
        FIBRE_FIELD=>EQUATIONS%INTERPOLATION%FIBRE_FIELD
        USE_FIBRES=ASSOCIATED(FIBRE_FIELD)
        EQUATIONS_MAPPING=>EQUATIONS%equationsMapping
        EQUATIONS_MATRICES=>EQUATIONS%equationsMatrices
        DEPENDENT_BASIS=>DEPENDENT_FIELD%DECOMPOSITION%DOMAIN(DEPENDENT_FIELD%DECOMPOSITION%MESH_COMPONENT_NUMBER)%PTR% &
          & TOPOLOGY%ELEMENTS%ELEMENTS(ELEMENT_NUMBER)%BASIS
        GEOMETRIC_BASIS=>GEOMETRIC_FIELD%DECOMPOSITION%DOMAIN(GEOMETRIC_FIELD%DECOMPOSITION%MESH_COMPONENT_NUMBER)%PTR% &
          & TOPOLOGY%ELEMENTS%ELEMENTS(ELEMENT_NUMBER)%BASIS
        GEOMETRIC_VARIABLE=>GEOMETRIC_FIELD%VARIABLE_TYPE_MAP(FIELD_U_VARIABLE_TYPE)%PTR
        IF(USE_FIBRES) FIBRE_BASIS=>FIBRE_FIELD%DECOMPOSITION%DOMAIN(GEOMETRIC_FIELD%DECOMPOSITION%MESH_COMPONENT_NUMBER)%PTR% &
          & TOPOLOGY%ELEMENTS%ELEMENTS(ELEMENT_NUMBER)%BASIS
        QUADRATURE_SCHEME=>DEPENDENT_BASIS%QUADRATURE%QUADRATURE_SCHEME_MAP(BASIS_DEFAULT_QUADRATURE_SCHEME)%PTR
        CALL FIELD_INTERPOLATION_PARAMETERS_ELEMENT_GET(FIELD_VALUES_SET_TYPE,ELEMENT_NUMBER,EQUATIONS%INTERPOLATION% &
          & GEOMETRIC_INTERP_PARAMETERS(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
        CALL FIELD_INTERPOLATION_PARAMETERS_ELEMENT_GET(FIELD_VALUES_SET_TYPE,ELEMENT_NUMBER,EQUATIONS%INTERPOLATION% &
          & MATERIALS_INTERP_PARAMETERS(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
        IF(USE_FIBRES) CALL FIELD_INTERPOLATION_PARAMETERS_ELEMENT_GET(FIELD_VALUES_SET_TYPE,ELEMENT_NUMBER,EQUATIONS% &
          & INTERPOLATION%FIBRE_INTERP_PARAMETERS(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
        IF(EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_CELLML_REAC_NO_SPLIT_REAC_DIFF_SUBTYPE .OR. &
            & EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_CONSTANT_REAC_DIFF_SUBTYPE) THEN
           CALL FIELD_INTERPOLATION_PARAMETERS_ELEMENT_GET(FIELD_VALUES_SET_TYPE,ELEMENT_NUMBER,EQUATIONS%INTERPOLATION% &
             & SOURCE_INTERP_PARAMETERS(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
        ENDIF                  
        DYNAMIC_MATRICES=>EQUATIONS_MATRICES%DYNAMIC_MATRICES
        STIFFNESS_MATRIX=>DYNAMIC_MATRICES%MATRICES(1)%PTR
        DAMPING_MATRIX=>DYNAMIC_MATRICES%MATRICES(2)%PTR
        RHS_VECTOR=>EQUATIONS_MATRICES%RHS_VECTOR
        IF(EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_CELLML_REAC_NO_SPLIT_REAC_DIFF_SUBTYPE .OR. &
            & EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_CONSTANT_REAC_DIFF_SUBTYPE) THEN
           SOURCE_VECTOR=>EQUATIONS_MATRICES%SOURCE_VECTOR
        ENDIF
        DYNAMIC_MAPPING=>EQUATIONS_MAPPING%DYNAMIC_MAPPING
        FIELD_VARIABLE=>DYNAMIC_MAPPING%EQUATIONS_MATRIX_TO_VAR_MAPS(1)%VARIABLE
        FIELD_VAR_TYPE=FIELD_VARIABLE%VARIABLE_TYPE
        IF(STIFFNESS_MATRIX%UPDATE_MATRIX.OR.DAMPING_MATRIX%UPDATE_MATRIX.OR.RHS_VECTOR%UPDATE_VECTOR) THEN
          !Loop over gauss points
          DO ng=1,QUADRATURE_SCHEME%NUMBER_OF_GAUSS
            CALL FIELD_INTERPOLATE_GAUSS(FIRST_PART_DERIV,BASIS_DEFAULT_QUADRATURE_SCHEME,ng,EQUATIONS%INTERPOLATION% &
              & GEOMETRIC_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
            CALL FIELD_INTERPOLATED_POINT_METRICS_CALCULATE(GEOMETRIC_BASIS%NUMBER_OF_XI,EQUATIONS%INTERPOLATION% &
              & GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
            CALL FIELD_INTERPOLATE_GAUSS(NO_PART_DERIV,BASIS_DEFAULT_QUADRATURE_SCHEME,ng,EQUATIONS%INTERPOLATION% &
              & MATERIALS_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
            IF(USE_FIBRES) THEN
              CALL FIELD_INTERPOLATE_GAUSS(FIRST_PART_DERIV,BASIS_DEFAULT_QUADRATURE_SCHEME,ng,EQUATIONS%INTERPOLATION% &
                & FIBRE_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
              CALL FIELD_INTERPOLATED_POINT_METRICS_CALCULATE(FIBRE_BASIS%NUMBER_OF_XI,EQUATIONS%INTERPOLATION% &
                & FIBRE_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
            ENDIF
            IF(EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_CELLML_REAC_NO_SPLIT_REAC_DIFF_SUBTYPE .OR. &
            & EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_CONSTANT_REAC_DIFF_SUBTYPE) THEN
              CALL FIELD_INTERPOLATE_GAUSS(NO_PART_DERIV,BASIS_DEFAULT_QUADRATURE_SCHEME,ng,EQUATIONS%INTERPOLATION% &
                & SOURCE_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
            ENDIF
            !Calculate RWG.
            RWG=EQUATIONS%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR%JACOBIAN* &
              & QUADRATURE_SCHEME%GAUSS_WEIGHTS(ng)
            !Calculate the diffusivity tensor
            DIFFUSIVITY=0.0_DP
            IF(USE_FIBRES) THEN
              !Calculate the diffusivity tensor in fibre coordinates
              CALL FlagError("Not implemented.",ERR,ERROR,*999)
            ELSE
              !Use the diffusivity tensor in geometric coordinates
              DO nj=1,GEOMETRIC_VARIABLE%NUMBER_OF_COMPONENTS !first three components of material field are the diffusivities
                DIFFUSIVITY(nj,nj)=EQUATIONS%INTERPOLATION%MATERIALS_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR%VALUES(nj,1)
              ENDDO !nj
            ENDIF
            !Get the storage Coefficient, stored in the component after the diffusivities for each dimension
            component_idx=GEOMETRIC_VARIABLE%NUMBER_OF_COMPONENTS+1
            STORAGE_COEFFICIENT=EQUATIONS%INTERPOLATION%MATERIALS_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR%VALUES(component_idx,1)
            !Compute basis dPhi/dx terms
            DO nj=1,GEOMETRIC_VARIABLE%NUMBER_OF_COMPONENTS
              DO ms=1,DEPENDENT_BASIS%NUMBER_OF_ELEMENT_PARAMETERS
                DPHIDX(nj,ms)=0.0_DP
                DO ni=1,DEPENDENT_BASIS%NUMBER_OF_XI
                  DPHIDX(nj,ms)=DPHIDX(nj,ms)+ &
                    & QUADRATURE_SCHEME%GAUSS_BASIS_FNS(ms,PARTIAL_DERIVATIVE_FIRST_DERIVATIVE_MAP(ni),ng)* &
                    & EQUATIONS%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR%DXI_DX(ni,nj)
                ENDDO !ni
              ENDDO !ms
            ENDDO !nj            
            !Loop over field components
            mhs=0          
            DO mh=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS
              !Loop over element rows
              DO ms=1,DEPENDENT_BASIS%NUMBER_OF_ELEMENT_PARAMETERS
                mhs=mhs+1
                nhs=0
                !Loop over element columns
                DO nh=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS
                  DO ns=1,DEPENDENT_BASIS%NUMBER_OF_ELEMENT_PARAMETERS
                    nhs=nhs+1
                    SUM=0.0_DP
                    IF(STIFFNESS_MATRIX%UPDATE_MATRIX) THEN
                      DO ni=1,GEOMETRIC_VARIABLE%NUMBER_OF_COMPONENTS
                        DO nj=1,GEOMETRIC_VARIABLE%NUMBER_OF_COMPONENTS
                          SUM=SUM+DIFFUSIVITY(ni,nj)*DPHIDX(ni,mhs)*DPHIDX(nj,nhs)
                       ENDDO !nj
                      ENDDO !ni
                      STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)=STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)+(SUM*RWG)
                    ENDIF
                    IF(DAMPING_MATRIX%UPDATE_MATRIX) THEN
                      DAMPING_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)=DAMPING_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)+ &
                        & QUADRATURE_SCHEME%GAUSS_BASIS_FNS(ms,NO_PART_DERIV,ng)* &
                        & QUADRATURE_SCHEME%GAUSS_BASIS_FNS(ns,NO_PART_DERIV,ng)*STORAGE_COEFFICIENT*RWG
                    ENDIF
                  ENDDO !ns
                ENDDO !nh

                IF(RHS_VECTOR%UPDATE_VECTOR) RHS_VECTOR%ELEMENT_VECTOR%VECTOR(mhs)=0.0_DP
              ENDDO !ms
            ENDDO !mh
            IF(EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_CONSTANT_REAC_DIFF_SUBTYPE) THEN
              IF(SOURCE_VECTOR%UPDATE_VECTOR) THEN
                C_PARAM=EQUATIONS%INTERPOLATION%SOURCE_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR%VALUES(1,NO_PART_DERIV)
                mhs=0
                DO mh=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS
                !Loop over element rows
                  DO ms=1,DEPENDENT_BASIS%NUMBER_OF_ELEMENT_PARAMETERS
                    mhs=mhs+1
                    SOURCE_VECTOR%ELEMENT_VECTOR%VECTOR(mhs)=SOURCE_VECTOR%ELEMENT_VECTOR%VECTOR(mhs)+ &
                      & QUADRATURE_SCHEME%GAUSS_BASIS_FNS(ms,NO_PART_DERIV,ng)*C_PARAM*RWG
                  ENDDO
                ENDDO
              ENDIF
            ENDIF
            IF(RHS_VECTOR%UPDATE_VECTOR) RHS_VECTOR%ELEMENT_VECTOR%VECTOR(mhs)=0.0_DP
          ENDDO !ng
        ENDIF
        !Scale factor adjustment
        IF(DEPENDENT_FIELD%SCALINGS%SCALING_TYPE/=FIELD_NO_SCALING) THEN
          CALL Field_InterpolationParametersScaleFactorsElementGet(ELEMENT_NUMBER,EQUATIONS%INTERPOLATION% &
            & DEPENDENT_INTERP_PARAMETERS(FIELD_VAR_TYPE)%PTR,ERR,ERROR,*999)
          mhs=0          
          DO mh=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS
            !Loop over element rows
            DO ms=1,DEPENDENT_BASIS%NUMBER_OF_ELEMENT_PARAMETERS
              mhs=mhs+1                    
              nhs=0
              IF(STIFFNESS_MATRIX%UPDATE_MATRIX.OR.DAMPING_MATRIX%UPDATE_MATRIX) THEN
                !Loop over element columns
                DO nh=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS
                  DO ns=1,DEPENDENT_BASIS%NUMBER_OF_ELEMENT_PARAMETERS
                    nhs=nhs+1
                    IF(STIFFNESS_MATRIX%UPDATE_MATRIX) THEN
                      STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)=STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)* &
                        & EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_PARAMETERS(FIELD_VAR_TYPE)%PTR%SCALE_FACTORS(ms,mh)* &
                        & EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_PARAMETERS(FIELD_VAR_TYPE)%PTR%SCALE_FACTORS(ns,nh)
                    ENDIF
                    IF(DAMPING_MATRIX%UPDATE_MATRIX) THEN
                      DAMPING_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)=DAMPING_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)* &
                        & EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_PARAMETERS(FIELD_VAR_TYPE)%PTR%SCALE_FACTORS(ms,mh)* &
                        & EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_PARAMETERS(FIELD_VAR_TYPE)%PTR%SCALE_FACTORS(ns,nh)
                    ENDIF
                  ENDDO !ns
                ENDDO !nh
              ENDIF
              IF(RHS_VECTOR%UPDATE_VECTOR) RHS_VECTOR%ELEMENT_VECTOR%VECTOR(mhs)=RHS_VECTOR%ELEMENT_VECTOR%VECTOR(mhs)* &
                & EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_PARAMETERS(FIELD_VAR_TYPE)%PTR%SCALE_FACTORS(ms,mh)
              IF(EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_CONSTANT_REAC_DIFF_SUBTYPE) THEN
                 IF(SOURCE_VECTOR%UPDATE_VECTOR) SOURCE_VECTOR%ELEMENT_VECTOR%VECTOR(mhs)= & 
                    & SOURCE_VECTOR%ELEMENT_VECTOR%VECTOR(mhs)* &
                    & EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_PARAMETERS(FIELD_VAR_TYPE)%PTR%SCALE_FACTORS(ms,mh)
              ENDIF
            ENDDO !ms
          ENDDO !mh
        ENDIF
      ELSE
        CALL FlagError("Equations set equations is not associated.",ERR,ERROR,*999)
      ENDIF
    ELSE
      CALL FlagError("Equations set is not associated.",ERR,ERROR,*999)
    ENDIF
       
    EXITS("ReactionDiffusion_FiniteElementCalculate")
    RETURN
999 ERRORS("ReactionDiffusion_FiniteElementCalculate",ERR,ERROR)
    EXITS("ReactionDiffusion_FiniteElementCalculate")
    RETURN 1
    
  END SUBROUTINE ReactionDiffusion_FiniteElementCalculate

  !
  !================================================================================================================================
  !
  !>Sets the problem specification for a reaction-diffusion problem.
  SUBROUTINE ReactionDiffusion_ProblemSpecificationSet(problem,problemSpecification,err,error,*)

    !Argument variables
    TYPE(PROBLEM_TYPE), POINTER, INTENT(IN) :: problem !<A pointer to the problem to set the problem specification for.
    INTEGER(INTG), INTENT(IN) :: problemSpecification(:) !<The problem specification to set.
    INTEGER(INTG), INTENT(OUT) :: err !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: error !<The error string
    !Local Variables
    TYPE(VARYING_STRING) :: localError
    INTEGER(INTG) :: problemSubtype

    ENTERS("ReactionDiffusion_ProblemSpecificationSet",err,error,*999)

    IF(ASSOCIATED(problem)) THEN
      IF(SIZE(problemSpecification,1)>=3) THEN
        problemSubtype=problemSpecification(3)
        SELECT CASE(problemSubtype)
        CASE(PROBLEM_CELLML_REAC_INTEG_REAC_DIFF_STRANG_SPLIT_SUBTYPE, &
            & PROBLEM_CELLML_REAC_EVAL_REAC_DIFF_NO_SPLIT_SUBTYPE, &
            & PROBLEM_CONSTANT_REAC_DIFF_NO_SPLIT_SUBTYPE)
          !ok
        CASE DEFAULT
          localError="The specified problem subtype of "//TRIM(NumberToVstring(problemSubtype,"*",err,error))// &
            & " is not valid for a reaction-diffusion problem type of a classical problem class."
          CALL FlagError(localError,err,error,*999)
        END SELECT
        IF(ALLOCATED(problem%specification)) THEN
          CALL FlagError("Problem specification is already allocated.",err,error,*999)
        ELSE
          ALLOCATE(problem%specification(3),stat=err)
          IF(err/=0) CALL FlagError("Could not allocate problem specification.",err,error,*999)
        END IF
        problem%specification(1:3)=[PROBLEM_CLASSICAL_FIELD_CLASS,PROBLEM_REACTION_DIFFUSION_EQUATION_TYPE,problemSubtype]
      ELSE
        CALL FlagError("Reaction-diffusion problem specification must have >=3 entries.",err,error,*999)
      END IF
    ELSE
      CALL FlagError("Problem is not associated.",err,error,*999)
    END IF

    EXITS("ReactionDiffusion_ProblemSpecificationSet")
    RETURN
999 ERRORS("ReactionDiffusion_ProblemSpecificationSet",err,error)
    EXITS("ReactionDiffusion_ProblemSpecificationSet")
    RETURN 1
    
  END SUBROUTINE ReactionDiffusion_ProblemSpecificationSet

  !
  !================================================================================================================================
  !
  !>Sets up the reaction-diffusion problem.
  SUBROUTINE REACTION_DIFFUSION_EQUATION_PROBLEM_SETUP(PROBLEM,PROBLEM_SETUP,ERR,ERROR,*)

    !Argument variables
    TYPE(PROBLEM_TYPE), POINTER :: PROBLEM !<A pointer to the problem set to setup a bioelectric domain equation on.
    TYPE(PROBLEM_SETUP_TYPE), INTENT(INOUT) :: PROBLEM_SETUP !<The problem setup information
    INTEGER(INTG), INTENT(OUT) :: ERR !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: ERROR !<The error string
    !Local Variables
    TYPE(CELLML_EQUATIONS_TYPE), POINTER :: CELLML_EQUATIONS
    TYPE(CONTROL_LOOP_TYPE), POINTER :: CONTROL_LOOP,CONTROL_LOOP_ROOT
    TYPE(SOLVER_TYPE), POINTER :: SOLVER
    TYPE(SOLVER_EQUATIONS_TYPE), POINTER :: SOLVER_EQUATIONS
    TYPE(SOLVERS_TYPE), POINTER :: SOLVERS
    TYPE(VARYING_STRING) :: LOCAL_ERROR

    NULLIFY(CELLML_EQUATIONS)
    NULLIFY(CONTROL_LOOP)
    NULLIFY(SOLVER)
    NULLIFY(SOLVERS)
    NULLIFY(SOLVER_EQUATIONS)
    
    ENTERS("REACTION_DIFFUSION_EQUATION_PROBLEM_SETUP",ERR,ERROR,*999)

    IF(ASSOCIATED(PROBLEM)) THEN
      IF(.NOT.ALLOCATED(PROBLEM%SPECIFICATION)) THEN
        CALL FlagError("Problem specification is not allocated.",err,error,*999)
      ELSE IF(SIZE(PROBLEM%SPECIFICATION,1)<3) THEN
        CALL FlagError("Problem specification must have three entries for a reaction diffusion problem.",err,error,*999)
      END IF
      SELECT CASE(PROBLEM_SETUP%SETUP_TYPE)
      CASE(PROBLEM_SETUP_INITIAL_TYPE)
        SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
        CASE(PROBLEM_SETUP_START_ACTION)
          !Do nothing????
        CASE(PROBLEM_SETUP_FINISH_ACTION)
          !Do nothing????
        CASE DEFAULT
          LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
            & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
            & " is invalid for a reaction diffusion equation."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      CASE(PROBLEM_SETUP_CONTROL_TYPE)
        SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
        CASE(PROBLEM_SETUP_START_ACTION)
          !Set up a time control loop
          CALL CONTROL_LOOP_CREATE_START(PROBLEM,CONTROL_LOOP,ERR,ERROR,*999)
          CALL CONTROL_LOOP_TYPE_SET(CONTROL_LOOP,PROBLEM_CONTROL_TIME_LOOP_TYPE,ERR,ERROR,*999)
          CALL CONTROL_LOOP_LABEL_SET(CONTROL_LOOP,"Time Loop",ERR,ERROR,*999)
        CASE(PROBLEM_SETUP_FINISH_ACTION)
          !Finish the control loops
          CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
          CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
          CALL CONTROL_LOOP_CREATE_FINISH(CONTROL_LOOP,ERR,ERROR,*999)            
        CASE DEFAULT
          LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
            & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
            & " is invalid for a reaction-diffusion equation."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      CASE(PROBLEM_SETUP_SOLVERS_TYPE)
        !Get the control loop
        CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
        CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
        SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
        CASE(PROBLEM_SETUP_START_ACTION)
          !Start the solvers creation
          CALL SOLVERS_CREATE_START(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
          SELECT CASE(PROBLEM%SPECIFICATION(3))
          CASE(PROBLEM_CELLML_REAC_INTEG_REAC_DIFF_STRANG_SPLIT_SUBTYPE)
            CALL SOLVERS_NUMBER_SET(SOLVERS,3,ERR,ERROR,*999)
            !Set the first solver to be a differential-algebraic equations solver
            NULLIFY(SOLVER)
            CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
            CALL SOLVER_TYPE_SET(SOLVER,SOLVER_DAE_TYPE,ERR,ERROR,*999)
            CALL SOLVER_LABEL_SET(SOLVER,"First ODE solver",ERR,ERROR,*999)
            !Set solver defaults
            CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_CMISS_LIBRARY,ERR,ERROR,*999)
            !Set the second solver to be a dynamic solver 
            NULLIFY(SOLVER)
            CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
            CALL SOLVER_TYPE_SET(SOLVER,SOLVER_DYNAMIC_TYPE,ERR,ERROR,*999)
            CALL SOLVER_DYNAMIC_ORDER_SET(SOLVER,SOLVER_DYNAMIC_FIRST_ORDER,ERR,ERROR,*999)
            CALL SOLVER_LABEL_SET(SOLVER,"Parabolic solver",ERR,ERROR,*999)
            !Set solver defaults
            CALL SOLVER_DYNAMIC_DEGREE_SET(SOLVER,SOLVER_DYNAMIC_FIRST_DEGREE,ERR,ERROR,*999)
            CALL SOLVER_DYNAMIC_SCHEME_SET(SOLVER,SOLVER_DYNAMIC_CRANK_NICOLSON_SCHEME,ERR,ERROR,*999)
            CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_CMISS_LIBRARY,ERR,ERROR,*999)
            !Set the third solver to be a differential-algebraic equations solver
            NULLIFY(SOLVER)
            CALL SOLVERS_SOLVER_GET(SOLVERS,3,SOLVER,ERR,ERROR,*999)
            CALL SOLVER_TYPE_SET(SOLVER,SOLVER_DAE_TYPE,ERR,ERROR,*999)
            CALL SOLVER_LABEL_SET(SOLVER,"Second ODE solver",ERR,ERROR,*999)
            !Set solver defaults
            CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_CMISS_LIBRARY,ERR,ERROR,*999)
          CASE(PROBLEM_CELLML_REAC_EVAL_REAC_DIFF_NO_SPLIT_SUBTYPE)
            CALL SOLVERS_NUMBER_SET(SOLVERS,2,ERR,ERROR,*999)
            !Set the first solver to be a CELLML evaluator equations solver
            NULLIFY(SOLVER)
            CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
            CALL SOLVER_TYPE_SET(SOLVER,SOLVER_CELLML_EVALUATOR_TYPE,ERR,ERROR,*999)
            CALL SOLVER_LABEL_SET(SOLVER,"Evaluator solver",ERR,ERROR,*999)
            !Set solver defaults
            CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_CMISS_LIBRARY,ERR,ERROR,*999)
            !Set the second solver to be a dynamic solver 
            NULLIFY(SOLVER)
            CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
            CALL SOLVER_TYPE_SET(SOLVER,SOLVER_DYNAMIC_TYPE,ERR,ERROR,*999)
            CALL SOLVER_DYNAMIC_ORDER_SET(SOLVER,SOLVER_DYNAMIC_FIRST_ORDER,ERR,ERROR,*999)
            CALL SOLVER_LABEL_SET(SOLVER,"Parabolic solver",ERR,ERROR,*999)
            !Set solver defaults
            CALL SOLVER_DYNAMIC_DEGREE_SET(SOLVER,SOLVER_DYNAMIC_FIRST_DEGREE,ERR,ERROR,*999)
            CALL SOLVER_DYNAMIC_SCHEME_SET(SOLVER,SOLVER_DYNAMIC_CRANK_NICOLSON_SCHEME,ERR,ERROR,*999)
            CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_CMISS_LIBRARY,ERR,ERROR,*999)
          CASE(PROBLEM_CONSTANT_REAC_DIFF_NO_SPLIT_SUBTYPE)
            CALL SOLVERS_NUMBER_SET(SOLVERS,1,ERR,ERROR,*999)
            !Set the solver to be a dynamic solver 
            NULLIFY(SOLVER)
            CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
            CALL SOLVER_TYPE_SET(SOLVER,SOLVER_DYNAMIC_TYPE,ERR,ERROR,*999)
            CALL SOLVER_DYNAMIC_ORDER_SET(SOLVER,SOLVER_DYNAMIC_FIRST_ORDER,ERR,ERROR,*999)
            CALL SOLVER_LABEL_SET(SOLVER,"Parabolic solver",ERR,ERROR,*999)
            !Set solver defaults
            CALL SOLVER_DYNAMIC_DEGREE_SET(SOLVER,SOLVER_DYNAMIC_FIRST_DEGREE,ERR,ERROR,*999)
            CALL SOLVER_DYNAMIC_SCHEME_SET(SOLVER,SOLVER_DYNAMIC_CRANK_NICOLSON_SCHEME,ERR,ERROR,*999)
            CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_CMISS_LIBRARY,ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The problem subtype of "//TRIM(NUMBER_TO_VSTRING(PROBLEM%SPECIFICATION(3),"*",ERR,ERROR))// &
              & " is invalid for a reaction-diffusion problem type of a classical problem class."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE(PROBLEM_SETUP_FINISH_ACTION)
          !Get the solvers
          CALL CONTROL_LOOP_SOLVERS_GET(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
          !Finish the solvers creation
          CALL SOLVERS_CREATE_FINISH(SOLVERS,ERR,ERROR,*999)
        CASE DEFAULT
          LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
            & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
            & " is invalid for a classical equation."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      CASE(PROBLEM_SETUP_SOLVER_EQUATIONS_TYPE)
        SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
        CASE(PROBLEM_SETUP_START_ACTION)
          !Get the control loop
          CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
          CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
          SELECT CASE(PROBLEM%SPECIFICATION(3))
          CASE(PROBLEM_CELLML_REAC_INTEG_REAC_DIFF_STRANG_SPLIT_SUBTYPE)
            !Get the solver
            CALL CONTROL_LOOP_SOLVERS_GET(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
            !Create the solver equations for the second (parabolic) solver
            CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
            CALL SOLVER_EQUATIONS_CREATE_START(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
            CALL SOLVER_EQUATIONS_LINEARITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_LINEAR,ERR,ERROR,*999)
            CALL SOLVER_EQUATIONS_TIME_DEPENDENCE_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_FIRST_ORDER_DYNAMIC,ERR,ERROR,*999)
            CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
          CASE(PROBLEM_CELLML_REAC_EVAL_REAC_DIFF_NO_SPLIT_SUBTYPE)
            !Get the solver
            CALL CONTROL_LOOP_SOLVERS_GET(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
            !Create the solver equations for the parabolic solver
            CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
            CALL SOLVER_EQUATIONS_CREATE_START(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
            CALL SOLVER_EQUATIONS_LINEARITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_NONLINEAR,ERR,ERROR,*999)
            CALL SOLVER_EQUATIONS_TIME_DEPENDENCE_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_FIRST_ORDER_DYNAMIC,ERR,ERROR,*999)
            CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
          CASE(PROBLEM_CONSTANT_REAC_DIFF_NO_SPLIT_SUBTYPE)
            !Get the solver
            CALL CONTROL_LOOP_SOLVERS_GET(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
            !Create the solver equations for the parabolic solver
            CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
            CALL SOLVER_EQUATIONS_CREATE_START(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
            CALL SOLVER_EQUATIONS_LINEARITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_LINEAR,ERR,ERROR,*999)
            CALL SOLVER_EQUATIONS_TIME_DEPENDENCE_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_FIRST_ORDER_DYNAMIC,ERR,ERROR,*999)
            CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
              & " for a setup subtype of "//TRIM(NUMBER_TO_VSTRING(PROBLEM%SPECIFICATION(3),"*",ERR,ERROR))// &
              & " is invalid for a reaction-diffusion equation."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT

        CASE(PROBLEM_SETUP_FINISH_ACTION)
          !Get the control loop
          CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
          CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
          CALL CONTROL_LOOP_SOLVERS_GET(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
          SELECT CASE(PROBLEM%SPECIFICATION(3))
          CASE(PROBLEM_CELLML_REAC_INTEG_REAC_DIFF_STRANG_SPLIT_SUBTYPE)
            !Get the solver equations for the second (parabolic) solver
            CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
            CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
            !Finish the solver equations creation
            CALL SOLVER_EQUATIONS_CREATE_FINISH(SOLVER_EQUATIONS,ERR,ERROR,*999)             
          CASE(PROBLEM_CELLML_REAC_EVAL_REAC_DIFF_NO_SPLIT_SUBTYPE)
            !Get the solver equations for the parabolic solver
            CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
            CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
            !Finish the solver equations creation
            CALL SOLVER_EQUATIONS_CREATE_FINISH(SOLVER_EQUATIONS,ERR,ERROR,*999)             
          CASE(PROBLEM_CONSTANT_REAC_DIFF_NO_SPLIT_SUBTYPE)
            !Get the solver equations for thE solver
            CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
            CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
            !Finish the solver equations creation
            CALL SOLVER_EQUATIONS_CREATE_FINISH(SOLVER_EQUATIONS,ERR,ERROR,*999)             
          CASE DEFAULT
            LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
              & " for a setup subtype of "//TRIM(NUMBER_TO_VSTRING(PROBLEM%SPECIFICATION(3),"*",ERR,ERROR))// &
              & " is invalid for a reaction-diffusion equation."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE DEFAULT
          LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
            & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
            & " is invalid for a reaction-diffusion equation."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      CASE(PROBLEM_SETUP_CELLML_EQUATIONS_TYPE)
        SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
        CASE(PROBLEM_SETUP_START_ACTION)
          !Get the control loop
          CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
          CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
          !Get the solver
          CALL CONTROL_LOOP_SOLVERS_GET(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)

          IF(PROBLEM%SPECIFICATION(3)==PROBLEM_CELLML_REAC_INTEG_REAC_DIFF_STRANG_SPLIT_SUBTYPE) THEN
            NULLIFY(SOLVER)
            NULLIFY(CELLML_EQUATIONS)
            !Create the CellML equations for the first DAE solver
            CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
            CALL CELLML_EQUATIONS_CREATE_START(SOLVER,CELLML_EQUATIONS,ERR,ERROR,*999)
            !Set the time dependence
            CALL CellMLEquations_TimeDependenceTypeSet(CELLML_EQUATIONS,CELLML_EQUATIONS_DYNAMIC,err,error,*999)
            !Set the linearity
            CALL CellMLEquations_LinearityTypeSet(CELLML_EQUATIONS,CELLML_EQUATIONS_NONLINEAR,err,error,*999)
            !Create the CellML equations for the second DAE solver
            NULLIFY(SOLVER)
            NULLIFY(CELLML_EQUATIONS)
            CALL SOLVERS_SOLVER_GET(SOLVERS,3,SOLVER,ERR,ERROR,*999)
            CALL CELLML_EQUATIONS_CREATE_START(SOLVER,CELLML_EQUATIONS,ERR,ERROR,*999)
            !Set the time dependence
            CALL CellMLEquations_TimeDependenceTypeSet(CELLML_EQUATIONS,CELLML_EQUATIONS_DYNAMIC,err,error,*999)
            !Set the linearity
            CALL CellMLEquations_LinearityTypeSet(CELLML_EQUATIONS,CELLML_EQUATIONS_NONLINEAR,err,error,*999)
          ELSEIF(PROBLEM%SPECIFICATION(3)== &
           & PROBLEM_CELLML_REAC_EVAL_REAC_DIFF_NO_SPLIT_SUBTYPE) THEN
            !CREATE the CellML equations for the first evaluator solver
            NULLIFY(SOLVER)
            NULLIFY(CELLML_EQUATIONS)
            !Create the CellML equations for the first cellml evaluator solver
            CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
            CALL CELLML_EQUATIONS_CREATE_START(SOLVER,CELLML_EQUATIONS,ERR,ERROR,*999)
            !Set the time dependence
            CALL CellMLEquations_TimeDependenceTypeSet(CELLML_EQUATIONS,CELLML_EQUATIONS_DYNAMIC,err,error,*999)
            !Set the linearity
            CALL CellMLEquations_LinearityTypeSet(CELLML_EQUATIONS,CELLML_EQUATIONS_NONLINEAR,err,error,*999)
          ENDIF
        CASE(PROBLEM_SETUP_FINISH_ACTION)
          !Get the control loop
          CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
          CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
          CALL CONTROL_LOOP_SOLVERS_GET(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
          SELECT CASE(PROBLEM%SPECIFICATION(3))
          CASE(PROBLEM_CELLML_REAC_INTEG_REAC_DIFF_STRANG_SPLIT_SUBTYPE)
            !Get the CellML equations for the first DAE solver
            CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
            CALL SOLVER_CELLML_EQUATIONS_GET(SOLVER,CELLML_EQUATIONS,ERR,ERROR,*999)
            !Finish the CellML equations creation
            CALL CELLML_EQUATIONS_CREATE_FINISH(CELLML_EQUATIONS,ERR,ERROR,*999)
            !Get the CellML equations for the second DAE solver
            NULLIFY(SOLVER)
            NULLIFY(CELLML_EQUATIONS)
            CALL SOLVERS_SOLVER_GET(SOLVERS,3,SOLVER,ERR,ERROR,*999)
            CALL SOLVER_CELLML_EQUATIONS_GET(SOLVER,CELLML_EQUATIONS,ERR,ERROR,*999)
            !Finish the CellML equations creation
            CALL CELLML_EQUATIONS_CREATE_FINISH(CELLML_EQUATIONS,ERR,ERROR,*999)
          CASE(PROBLEM_CELLML_REAC_EVAL_REAC_DIFF_NO_SPLIT_SUBTYPE)
            !Get the CellML equations for the first evaluator solver
            CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
            CALL SOLVER_CELLML_EQUATIONS_GET(SOLVER,CELLML_EQUATIONS,ERR,ERROR,*999)
            !Finish the CellML equations creation
            CALL CELLML_EQUATIONS_CREATE_FINISH(CELLML_EQUATIONS,ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
              & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM%SPECIFICATION(3),"*",ERR,ERROR))// &
              & " is invalid for reaction-diffusion equation."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE DEFAULT
          LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
            & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
            & " is invalid for reaction-diffusion equation."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      CASE DEFAULT
        LOCAL_ERROR="The setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
          & " is invalid for areaction-diffusion equation."
        CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
      END SELECT
    ELSE
      CALL FlagError("Problem is not associated.",ERR,ERROR,*999)
    ENDIF
      
    EXITS("REACTION_DIFFUSION_EQUATION_PROBLEM_SETUP")
    RETURN
999 ERRORSEXITS("REACTION_DIFFUSION_EQUATION_PROBLEM_SETUP",ERR,ERROR)
    RETURN 1
  END SUBROUTINE REACTION_DIFFUSION_EQUATION_PROBLEM_SETUP
  
  !
  !================================================================================================================================
  !
  !>Performs pre-solve actions for reaction-diffusion problems.
  SUBROUTINE REACTION_DIFFUSION_PRE_SOLVE(SOLVER,ERR,ERROR,*)

    !Argument variables
    TYPE(SOLVER_TYPE), POINTER :: SOLVER !<A pointer to the solver to perform the pre-solve actions for.
    INTEGER(INTG), INTENT(OUT) :: ERR !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: ERROR !<The error string
    !Local Variables
    REAL(DP) :: CURRENT_TIME,TIME_INCREMENT
    TYPE(CONTROL_LOOP_TYPE), POINTER :: CONTROL_LOOP
    TYPE(PROBLEM_TYPE), POINTER :: PROBLEM
    TYPE(SOLVERS_TYPE), POINTER :: SOLVERS
    TYPE(VARYING_STRING) :: LOCAL_ERROR

    ENTERS("REACTION_DIFFUSION_PRE_SOLVE",ERR,ERROR,*999)

    IF(ASSOCIATED(SOLVER)) THEN
      SOLVERS=>SOLVER%SOLVERS
      IF(ASSOCIATED(SOLVERS)) THEN
        CONTROL_LOOP=>SOLVERS%CONTROL_LOOP
        IF(ASSOCIATED(CONTROL_LOOP)) THEN
          CALL CONTROL_LOOP_CURRENT_TIMES_GET(CONTROL_LOOP,CURRENT_TIME,TIME_INCREMENT,ERR,ERROR,*999)
          PROBLEM=>CONTROL_LOOP%PROBLEM
          IF(ASSOCIATED(PROBLEM)) THEN
            SELECT CASE(PROBLEM%SPECIFICATION(3))
            CASE(PROBLEM_CELLML_REAC_INTEG_REAC_DIFF_STRANG_SPLIT_SUBTYPE)
              SELECT CASE(SOLVER%GLOBAL_NUMBER)
              CASE(1)
                CALL SOLVER_DAE_TIMES_SET(SOLVER,CURRENT_TIME,CURRENT_TIME+TIME_INCREMENT/2.0_DP,ERR,ERROR,*999)
              CASE(2)
                !Do nothing
              CASE(3)
                CALL SOLVER_DAE_TIMES_SET(SOLVER,CURRENT_TIME,CURRENT_TIME+TIME_INCREMENT/2.0_DP, &
                  & ERR,ERROR,*999)
              CASE DEFAULT
                LOCAL_ERROR="The solver global number of "//TRIM(NUMBER_TO_VSTRING(SOLVER%GLOBAL_NUMBER,"*",ERR,ERROR))// &
                  & " is invalid for a Strang split reaction-diffusion problem."
                CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE(PROBLEM_CONSTANT_REAC_DIFF_NO_SPLIT_SUBTYPE)
              !No splitting, therefore entire problem is solved as a dynamic one, with 1 solver nothing to do.
            CASE(PROBLEM_CELLML_REAC_EVAL_REAC_DIFF_NO_SPLIT_SUBTYPE)
              !No splitting, therefore entire problem is solved as a dynamic one, with 1 solver nothing to do.
            CASE DEFAULT
              LOCAL_ERROR="The problem subtype of "//TRIM(NUMBER_TO_VSTRING(PROBLEM%SPECIFICATION(3),"*",ERR,ERROR))// &
                & " is invalid for a reaction-diffusion problem type."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          ELSE
            CALL FlagError("Control loop problem is not associated.",ERR,ERROR,*999)
          ENDIF
        ELSE
          CALL FlagError("Solvers control loop is not associated.",ERR,ERROR,*999)
        ENDIF
      ELSE
        CALL FlagError("Solver solvers is not associated.",ERR,ERROR,*999)
      ENDIF
    ELSE
      CALL FlagError("Solver is not associated.",ERR,ERROR,*999)
    ENDIF
       
    EXITS("REACTION_DIFFUSION_PRE_SOLVE")
    RETURN
999 ERRORSEXITS("REACTION_DIFFUSION_PRE_SOLVE",ERR,ERROR)
    RETURN 1
    
  END SUBROUTINE REACTION_DIFFUSION_PRE_SOLVE

  !
  !================================================================================================================================
  !

  !>Sets up the reaction diffusion problem post solve.
  SUBROUTINE REACTION_DIFFUSION_POST_SOLVE(CONTROL_LOOP,SOLVER,ERR,ERROR,*)

    !Argument variables
    TYPE(CONTROL_LOOP_TYPE), POINTER :: CONTROL_LOOP !<A pointer to the control loop to solve.
    TYPE(SOLVER_TYPE), POINTER :: SOLVER!<A pointer to the solver
    INTEGER(INTG), INTENT(OUT) :: ERR !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: ERROR !<The error string
    !Local Variables
    TYPE(SOLVERS_TYPE), POINTER :: SOLVERS
    TYPE(SOLVER_TYPE), POINTER :: PDE_SOLVER
    TYPE(VARYING_STRING) :: LOCAL_ERROR

    ENTERS("REACTION_DIFFUSION_POST_SOLVE",ERR,ERROR,*999)

    IF(ASSOCIATED(CONTROL_LOOP)) THEN
      IF(ASSOCIATED(SOLVER)) THEN
        IF(ASSOCIATED(CONTROL_LOOP%PROBLEM)) THEN 
          IF(.NOT.ALLOCATED(CONTROL_LOOP%PROBLEM%SPECIFICATION)) THEN
            CALL FlagError("Problem specification is not allocated.",err,error,*999)
          ELSE IF(SIZE(CONTROL_LOOP%PROBLEM%SPECIFICATION,1)<3) THEN
            CALL FlagError("Problem specification must have three entries for a reaction diffusion problem.",err,error,*999)
          END IF
          SELECT CASE(CONTROL_LOOP%PROBLEM%SPECIFICATION(3))
            CASE(PROBLEM_CELLML_REAC_INTEG_REAC_DIFF_STRANG_SPLIT_SUBTYPE)
              SELECT CASE(SOLVER%GLOBAL_NUMBER)
                CASE(1)

                !do nothing
                CASE(2)

                !do nothing
                CASE(3)
                  !OUTPUT SOLUTIONS AT EACH TIME STEP - should probably change this bit below to output 
                  !mesh solutions directly from the 3rd solver itself rather than by getting the 2nd solver.
                  !I just don't know how to work with cellml_equations to do this.
                  SOLVERS=>SOLVER%SOLVERS
                  NULLIFY(PDE_SOLVER)
                  CALL SOLVERS_SOLVER_GET(SOLVERS,2,PDE_SOLVER,ERR,ERROR,*999)
                  CALL REACTION_DIFFUSION_POST_SOLVE_OUTPUT_DATA(CONTROL_LOOP,PDE_SOLVER,ERR,ERROR,*999)
                CASE DEFAULT
                  LOCAL_ERROR="The solver global number of "//TRIM(NUMBER_TO_VSTRING(SOLVER%GLOBAL_NUMBER,"*",ERR,ERROR))// &
                    & " is invalid for a Strang split reaction-diffusion problem."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE (PROBLEM_CELLML_REAC_EVAL_REAC_DIFF_NO_SPLIT_SUBTYPE)
              !do nothing - time output not implemented
            CASE (PROBLEM_CONSTANT_REAC_DIFF_NO_SPLIT_SUBTYPE)
              !OUTPUT SOLUTIONS AT TIME STEP
              CALL REACTION_DIFFUSION_POST_SOLVE_OUTPUT_DATA(CONTROL_LOOP,SOLVER,ERR,ERROR,*999)
            CASE DEFAULT
              LOCAL_ERROR="Problem subtype "//TRIM(NUMBER_TO_VSTRING(CONTROL_LOOP%PROBLEM%SPECIFICATION(3),"*",ERR,ERROR))// &
                & " is not valid for a reaction diffusion type of a classical field problem class."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        ELSE
          CALL FlagError("Problem is not associated.",ERR,ERROR,*999)
        ENDIF
      ELSE
        CALL FlagError("Solver is not associated.",ERR,ERROR,*999)
      ENDIF
    ELSE
      CALL FlagError("Control loop is not associated.",ERR,ERROR,*999)
    ENDIF

    EXITS("REACTION_DIFFUSION_POST_SOLVE")
    RETURN
999 ERRORSEXITS("REACTION_DIFFUSION_POST_SOLVE",ERR,ERROR)
    RETURN 1
  END SUBROUTINE REACTION_DIFFUSION_POST_SOLVE
  !   
  !================================================================================================================================
  !

  SUBROUTINE REACTION_DIFFUSION_POST_SOLVE_OUTPUT_DATA(CONTROL_LOOP,SOLVER,ERR,ERROR,*)

    !Argument variables
    TYPE(CONTROL_LOOP_TYPE), POINTER :: CONTROL_LOOP !<A pointer to the control loop to solve.
    TYPE(SOLVER_TYPE), POINTER :: SOLVER!<A pointer to the solver
    INTEGER(INTG), INTENT(OUT) :: ERR !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: ERROR !<The error string
    !Local variables
    TYPE(SOLVER_EQUATIONS_TYPE), POINTER :: SOLVER_EQUATIONS  !<A pointer to the solver equations
    TYPE(SOLVER_MAPPING_TYPE), POINTER :: SOLVER_MAPPING !<A pointer to the solver mapping
    TYPE(EQUATIONS_SET_TYPE), POINTER :: EQUATIONS_SET !<A pointer to the equations set
    TYPE(VARYING_STRING) :: LOCAL_ERROR

    REAL(DP) :: CURRENT_TIME,TIME_INCREMENT
    INTEGER(INTG) :: EQUATIONS_SET_IDX,CURRENT_LOOP_ITERATION,OUTPUT_FREQUENCY
    INTEGER(INTG) :: myComputationalNodeNumber

    CHARACTER(28) :: FILE
    CHARACTER(28) :: OUTPUT_FILE

    ENTERS("REACTION_DIFFUSION_POST_SOLVE_OUTPUT_DATA",ERR,ERROR,*999)

    IF(ASSOCIATED(CONTROL_LOOP)) THEN
      IF(ASSOCIATED(SOLVER)) THEN
        IF(ASSOCIATED(CONTROL_LOOP%PROBLEM)) THEN
          IF(.NOT.ALLOCATED(CONTROL_LOOP%PROBLEM%SPECIFICATION)) THEN
            CALL FlagError("Problem specification is not allocated.",err,error,*999)
          ELSE IF(SIZE(CONTROL_LOOP%PROBLEM%SPECIFICATION,1)<3) THEN
            CALL FlagError("Problem specification must have three entries for a reaction diffusion problem.",err,error,*999)
          END IF
          SELECT CASE(CONTROL_LOOP%PROBLEM%SPECIFICATION(3))
            CASE(PROBLEM_CELLML_REAC_INTEG_REAC_DIFF_STRANG_SPLIT_SUBTYPE, &
              & PROBLEM_CONSTANT_REAC_DIFF_NO_SPLIT_SUBTYPE)
              CALL CONTROL_LOOP_CURRENT_TIMES_GET(CONTROL_LOOP,CURRENT_TIME,TIME_INCREMENT,ERR,ERROR,*999)
              SOLVER_EQUATIONS=>SOLVER%SOLVER_EQUATIONS
              IF(ASSOCIATED(SOLVER_EQUATIONS)) THEN
                SOLVER_MAPPING=>SOLVER_EQUATIONS%SOLVER_MAPPING
                IF(ASSOCIATED(SOLVER_MAPPING)) THEN
                  !Make sure the equations sets are up to date
                  DO equations_set_idx=1,SOLVER_MAPPING%NUMBER_OF_EQUATIONS_SETS
                    EQUATIONS_SET=>SOLVER_MAPPING%EQUATIONS_SETS(equations_set_idx)%PTR

                    CURRENT_LOOP_ITERATION=CONTROL_LOOP%TIME_LOOP%ITERATION_NUMBER
                    OUTPUT_FREQUENCY=CONTROL_LOOP%TIME_LOOP%OUTPUT_NUMBER
                    myComputationalNodeNumber = COMPUTATIONAL_NODE_NUMBER_GET(err,error)
                    IF(OUTPUT_FREQUENCY>0) THEN
                      IF(MOD(CURRENT_LOOP_ITERATION,OUTPUT_FREQUENCY)==0) THEN
                        IF(CONTROL_LOOP%TIME_LOOP%CURRENT_TIME<=CONTROL_LOOP%TIME_LOOP%STOP_TIME) THEN
                          IF(SOLVER_MAPPING%NUMBER_OF_EQUATIONS_SETS.EQ.1) THEN
                            IF(CURRENT_LOOP_ITERATION<10) THEN
                              WRITE(OUTPUT_FILE,'("TIME_STEP_SPEC_1.part",I2.2,".000",I0)') &
                              & myComputationalNodeNumber, CURRENT_LOOP_ITERATION
                            ELSE IF(CURRENT_LOOP_ITERATION<100) THEN
                              WRITE(OUTPUT_FILE,'("TIME_STEP_SPEC_1.part",I2.2,".00",I0)') &
                              & myComputationalNodeNumber,CURRENT_LOOP_ITERATION
                            ELSE IF(CURRENT_LOOP_ITERATION<1000) THEN
                              WRITE(OUTPUT_FILE,'("TIME_STEP_SPEC_1.part",I2.2,".0",I0)') &
                              & myComputationalNodeNumber,CURRENT_LOOP_ITERATION
                            ELSE IF(CURRENT_LOOP_ITERATION<10000) THEN
                              WRITE(OUTPUT_FILE,'("TIME_STEP_SPEC_1.part",I2.2,".",I0)') &
                              & CURRENT_LOOP_ITERATION
                            END IF
                          ELSE
                            IF(CURRENT_LOOP_ITERATION<10) THEN
                              WRITE(OUTPUT_FILE, '("TIME_STEP_SPEC_",I0,".part",I2.2,".000",I0)') &
                                & equations_set_idx,myComputationalNodeNumber,CURRENT_LOOP_ITERATION
                            ELSE IF(CURRENT_LOOP_ITERATION<100) THEN
                              WRITE(OUTPUT_FILE, '("TIME_STEP_SPEC_",I0,".part",I2.2,".00",I0)') &
                                & equations_set_idx,myComputationalNodeNumber,CURRENT_LOOP_ITERATION
                            ELSE IF(CURRENT_LOOP_ITERATION<1000) THEN
                              WRITE(OUTPUT_FILE, '("TIME_STEP_SPEC_",I0,".part",I2.2,".0",I0)') &
                                & equations_set_idx,myComputationalNodeNumber,CURRENT_LOOP_ITERATION
                            ELSE IF(CURRENT_LOOP_ITERATION<10000) THEN
                              WRITE(OUTPUT_FILE, '("TIME_STEP_SPEC_",I0,".part",I2.2,".",I0)') &
                                & equations_set_idx,myComputationalNodeNumber,CURRENT_LOOP_ITERATION
                            END IF
                          ENDIF
                          WRITE(*,*) OUTPUT_FILE
                          FILE=TRIM(OUTPUT_FILE)
                          CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"...",ERR,ERROR,*999)
                          CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"Now export fields... ",ERR,ERROR,*999)
                          CALL REACTION_DIFFUSION_IO_WRITE_CMGUI(EQUATIONS_SET%REGION,EQUATIONS_SET%GLOBAL_NUMBER,FILE, &
                            & ERR,ERROR,*999)

                          !CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,OUTPUT_FILE,ERR,ERROR,*999)
                          !CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"...",ERR,ERROR,*999)
                        ENDIF
                      ENDIF 
                    ENDIF
                  ENDDO
                ENDIF
              ENDIF
            CASE(PROBLEM_CELLML_REAC_EVAL_REAC_DIFF_NO_SPLIT_SUBTYPE)
              ! do nothing ???
              CALL FlagError("Not implemented.",ERR,ERROR,*999)
            CASE DEFAULT
              LOCAL_ERROR="Problem subtype "//TRIM(NUMBER_TO_VSTRING(CONTROL_LOOP%PROBLEM%SPECIFICATION(3),"*",ERR,ERROR))// &
                & " is not valid for an advection-diffusion equation type of a classical field problem class."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        ELSE
          CALL FlagError("Problem is not associated.",ERR,ERROR,*999)
        ENDIF
      ELSE
        CALL FlagError("Solver is not associated.",ERR,ERROR,*999)
      ENDIF
    ELSE
      CALL FlagError("Control loop is not associated.",ERR,ERROR,*999)
    ENDIF

    EXITS("REACTION_DIFFUSION_POST_SOLVE_OUTPUT_DATA")
    RETURN
999 ERRORSEXITS("REACTION_DIFFUSION_POST_SOLVE_OUTPUT_DATA",ERR,ERROR)
    RETURN 1
    
  END SUBROUTINE REACTION_DIFFUSION_POST_SOLVE_OUTPUT_DATA
  !
  !================================================================================================================================
  !

  SUBROUTINE REACTION_DIFFUSION_CONTROL_LOOP_POST_LOOP(CONTROL_LOOP,ERR,ERROR,*)

    !Argument variables
    TYPE(CONTROL_LOOP_TYPE), POINTER :: CONTROL_LOOP !<A pointer to the control loop to solve.
    INTEGER(INTG), INTENT(OUT) :: ERR !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: ERROR !<The error string
    !Local variables
    TYPE(PROBLEM_TYPE), POINTER :: PROBLEM
    TYPE(SOLVER_EQUATIONS_TYPE), POINTER :: SOLVER_EQUATIONS  !<A pointer to the solver equations
    TYPE(SOLVER_MAPPING_TYPE), POINTER :: SOLVER_MAPPING !<A pointer to the solver mapping
    TYPE(EquationsType), POINTER :: EQUATIONS !<A pointer to the equations
    TYPE(EQUATIONS_SET_TYPE), POINTER :: EQUATIONS_SET !<A pointer to the equations set
    TYPE(SOLVER_TYPE), POINTER :: SOLVER !<A pointer to the solver
    TYPE(SOLVERS_TYPE), POINTER :: SOLVERS !<A pointer to the solvers
    TYPE(EQUATIONS_MATRICES_TYPE), POINTER :: EQUATIONS_MATRICES
    TYPE(EQUATIONS_MATRICES_DYNAMIC_TYPE), POINTER :: DYNAMIC_MATRICES
    TYPE(EQUATIONS_MATRIX_TYPE), POINTER :: DAMPING_MATRIX,STIFFNESS_MATRIX
    
    ENTERS("REACTION_DIFFUSION_CONTROL_LOOP_POST_LOOP",ERR,ERROR,*999)
    
    NULLIFY(SOLVER)
    IF(ASSOCIATED(CONTROL_LOOP)) THEN
      PROBLEM=>CONTROL_LOOP%PROBLEM
      IF(ASSOCIATED(PROBLEM)) THEN
        SELECT CASE(PROBLEM%SPECIFICATION(3))
        CASE(PROBLEM_CELLML_REAC_INTEG_REAC_DIFF_STRANG_SPLIT_SUBTYPE)
          SOLVERS=>CONTROL_LOOP%SOLVERS
          IF(ASSOCIATED(SOLVERS)) THEN
            CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
            SOLVER_EQUATIONS=>SOLVER%SOLVER_EQUATIONS
            IF(ASSOCIATED(SOLVER_EQUATIONS)) THEN
              SOLVER_MAPPING=>SOLVER_EQUATIONS%SOLVER_MAPPING
              IF(ASSOCIATED(SOLVER_MAPPING)) THEN
                EQUATIONS_SET=>SOLVER_MAPPING%EQUATIONS_SETS(1)%PTR
                IF(ASSOCIATED(EQUATIONS_SET)) THEN
                  EQUATIONS=>EQUATIONS_SET%EQUATIONS
                  IF(ASSOCIATED(EQUATIONS)) THEN
                    EQUATIONS_MATRICES=>EQUATIONS%equationsMatrices
                    DYNAMIC_MATRICES=>EQUATIONS_MATRICES%DYNAMIC_MATRICES
                    STIFFNESS_MATRIX=>DYNAMIC_MATRICES%MATRICES(1)%PTR
                    DAMPING_MATRIX=>DYNAMIC_MATRICES%MATRICES(2)%PTR
                    STIFFNESS_MATRIX%UPDATE_MATRIX = .FALSE.
                    DAMPING_MATRIX%UPDATE_MATRIX = .FALSE.
                  ELSE
                    CALL FlagError("Equations not associated.",ERR,ERROR,*999)
                  ENDIF
                ELSE
                  CALL FlagError("Equations Set not associated.",ERR,ERROR,*999)
                ENDIF
      
              ELSE
                CALL FlagError("Solver Mapping not associated.",ERR,ERROR,*999)
              ENDIF
            ELSE
              CALL FlagError("Solver Equations not associated.", ERR,ERROR,*999)
            ENDIF
          ELSE
            CALL FlagError("Solvers is not associated.", ERR,ERROR,*999)
          ENDIF


        CASE DEFAULT
          !do nothing
        END SELECT
      ELSE
        CALL FlagError("Problem is not associated.",ERR,ERROR,*999)
      ENDIF
    ELSE
      CALL FlagError("Control Loop is not associated.",ERR,ERROR,*999)
    ENDIF
    EXITS("REACTION_DIFFUSION_CONTROL_LOOP_POST_LOOP")
    RETURN
999 ERRORSEXITS("REACTION_DIFFUSION_CONTROL_LOOP_POST_LOOP",ERR,ERROR)
    RETURN 1
  END SUBROUTINE REACTION_DIFFUSION_CONTROL_LOOP_POST_LOOP
END MODULE REACTION_DIFFUSION_EQUATION_ROUTINES
