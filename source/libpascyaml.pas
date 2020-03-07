(******************************************************************************)
(*                                libPasCYAML                                 *)
(*               object pascal wrapper around libcyaml library                *)
(*                      https://github.com/tlsa/libcyaml                      *)
(*                                                                            *)
(* Copyright (c) 2020                                       Ivan Semenkov     *)
(* https://github.com/isemenkov/libpascyaml                 ivan@semenkov.pro *)
(*                                                          Ukraine           *)
(******************************************************************************)
(*                                                                            *)
(* This source  is free software;  you can redistribute  it and/or modify  it *)
(* under the terms of the GNU General Public License as published by the Free *)
(* Software Foundation; either version 3 of the License.                      *)
(*                                                                            *)
(* This code is distributed in the  hope that it will  be useful, but WITHOUT *)
(* ANY  WARRANTY;  without even  the implied  warranty of MERCHANTABILITY  or *)
(* FITNESS FOR A PARTICULAR PURPOSE.  See the  GNU General Public License for *)
(* more details.                                                              *)
(*                                                                            *)
(* A copy  of the  GNU General Public License is available  on the World Wide *)
(* Web at <http://www.gnu.org/copyleft/gpl.html>. You  can also obtain  it by *)
(* writing to the Free Software Foundation, Inc., 51  Franklin Street - Fifth *)
(* Floor, Boston, MA 02110-1335, USA.                                         *)
(*                                                                            *)
(******************************************************************************)

unit libpascyaml;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

{$IFDEF FPC}
  {$PACKRECORDS C}
{$ENDIF}

type
  cyaml_type = (
    { Value is a signed integer. }
    CYAML_INT,
    { Value is an unsigned signed integer. }
    CYAML_UINT,
    { Value is a boolean. }
    CYAML_BOOL,
    { Value is an enum.  Values of this type require a string / value mapping
      array in the schema entry, to define the list of valid enum values. }
    CYAML_ENUM,
    { Value is a flags bit field.  Values of this type require a string / value
      list in the schema entry, to define the list of valid flag values.  Each
      bit is a boolean flag.  To store values of various bit sizes, use a \ref
      CYAML_BITFIELD instead.

      In the YAML, a \ref CYAML_FLAGS value must be presented as a sequence of
      strings. }
    CYAML_FLAGS,
    { Value is floating point. }
    CYAML_FLOAT,
    { Value is a string. }
    CYAML_STRING,
    { Value is a mapping.  Values of this type require mapping schema array in
      the schema entry. }
    CYAML_MAPPING,
    { Value is a bit field.  Values of this type require an array of value
      definitions in the schema entry.  If the bitfield is used to store only
      single-bit flags, it may be better to use \ref CYAML_FLAGS instead.

      In the YAML, a \ref CYAML_FLAGS value must be presented as a mapping of
      bitfield entry names to their numerical values. }
    CYAML_BITFIELD,
    { Value is a sequence.  Values of this type must be the direct children of a
      mapping.  They require:

      - A schema describing the type of the sequence entries.
      - Offset to the array entry count member in the mapping structure.
      - Size in bytes of the count member in the mapping structure.
      - The minimum and maximum number of sequence count entries.
      Set `max` to \ref CYAML_UNLIMITED to make array count unconstrained. }
    CYAML_SEQUENCE,
    { Value is a **fixed length** sequence.  It is similar to \ref
      CYAML_SEQUENCE, however:

      - Values of this type do not need to be direct children of a mapping.
      - The minimum and maximum entry count must be the same.  If not
        \ref CYAML_ERR_SEQUENCE_FIXED_COUNT will be returned.
      - Thee offset and size of the count structure member is unused.
      Because the count is a schema-defined constant, it does not need to be
      recorded. }
    CYAML_SEQUENCE_FIXED,
    { Value of this type is completely ignored.  This is most useful for
      ignoring particular keys in a mapping, when CYAML client sets
      configuration of \ref CYAML_CFG_IGNORE_UNKNOWN_KEYS. }
    CYAML_IGNORE,
    { Count of the valid CYAML types.  This value is **not a valid type**
      itself. }
    CYAML__TYPE_COUNT
  );
  cyaml_type_e = cyaml_type;

  { CYAML value flags.
    These may be bitwise-ORed together. }
  cyaml_flag = (
    { Default value flags (none set). }
    CYAML_FLAG_DEFAULT                                               = 0,
    { Mapping field is optional. }
    CYAML_FLAG_OPTIONAL                                              = 1 shl 0,
    { Value is a pointer to its type.
      With this there must be a non-NULL value.  Consider using \ref
      CYAML_FLAG_POINTER_NULL or \ref CYAML_FLAG_POINTER_NULL_STR if you want to
      allow NULL values. }
    CYAML_FLAG_POINTER                                               = 1 shl 1,
    { Permit `NULL` values for \ref CYAML_FLAG_POINTER types.
      An empty value in the YAML is loaded as a NULL pointer, and NULL pointers
      are saved in YAML as empty values.
      Note, when you set \ref CYAML_FLAG_POINTER_NULL, then
      \ref CYAML_FLAG_POINTER is set automatically. }
    CYAML_FLAG_POINTER_NULL                   = (1 shl 2) or CYAML_FLAG_POINTER,
    { Permit storage of `NULL` values as special NULL strings in YAML.
      This extends \ref CYAML_FLAG_POINTER_NULL, but in addition to treating
      empty values as NULL, any of the following are also treated as NULL:
      * `null`,
      * `Null`,
      * `NULL`,
      * `~`,
      Note that as a side effect, loading a \ref CYAML_STRING field with one of
      these values will not store the literal string, it will store NULL.
      When saving, a NULL value will be recorded in the YAML as `null`.
      Note, when you set \ref CYAML_FLAG_POINTER_NULL_STR, then both
      \ref CYAML_FLAG_POINTER and \ref CYAML_FLAG_POINTER_NULL are set
      automatically. }
    CYAML_FLAG_POINTER_NULL_STR          = (1 shl 3) or CYAML_FLAG_POINTER_NULL,
    { Make value handling strict.
      For \ref CYAML_ENUM and \ref CYAML_FLAGS types, in strict mode the YAML
      must contain a matching string.  Without strict, numerical values are also
      permitted.
      * For \ref CYAML_ENUM, the value becomes the value of the enum.
      The numerical value is treated as signed.
      * For \ref CYAML_FLAGS, the values are bitwise ORed together.
      The numerical values are treated as unsigned. }
    CYAML_FLAG_STRICT                                                = 1 shl 4,
    { When saving, emit mapping / sequence value in block style.
      This can be used to override, for this value, any default style set in the
      \ref cyaml_cfg_flags CYAML behavioural configuration flags.
      \note This is ignored unless the value's type is \ref CYAML_MAPPING,
      \ref CYAML_SEQUENCE, or \ref CYAML_SEQUENCE_FIXED.
      \note If both \ref CYAML_FLAG_BLOCK and \ref CYAML_FLAG_FLOW are set, then
      block style takes precedence.
      \note If neither block nor flow style set either here, or in the
      \ref cyaml_cfg_flags CYAML behavioural configuration flags, then libyaml's
      default behaviour is used. }
    CYAML_FLAG_BLOCK                                                 = 1 shl 5,
    { When saving, emit mapping / sequence value in flow style.
      This can be used to override, for this value, any default style set in the
      \ref cyaml_cfg_flags CYAML behavioural configuration flags.
      \note This is ignored unless the value's type is \ref CYAML_MAPPING,
      \ref CYAML_SEQUENCE, or \ref CYAML_SEQUENCE_FIXED.
      \note If both \ref CYAML_FLAG_BLOCK and \ref CYAML_FLAG_FLOW are set, then
      block style takes precedence.
      \note If neither block nor flow style set either here, or in the
      \ref cyaml_cfg_flags CYAML behavioural configuration flags, then libyaml's
      default behaviour is used. }
    CYAML_FLAG_FLOW                                                  = 1 shl 6,
    { When comparing strings for this value, compare with case sensitivity.
      By default, strings are compared with case sensitivity.
      If \ref CYAML_CFG_CASE_INSENSITIVE is set, this can override the
      configured behaviour for this specific value.
      \note If both \ref CYAML_FLAG_CASE_SENSITIVE and
      \ref CYAML_FLAG_CASE_INSENSITIVE are set, then case insensitive takes
      precedence.
      \note This applies to values of types \ref CYAML_MAPPING,
      \ref CYAML_ENUM, and \ref CYAML_FLAGS.  For mappings, it applies to
      matching of the mappings' keys.  For enums and flags it applies to the
      comparison of \ref cyaml_strval strings. }
    CYAML_FLAG_CASE_SENSITIVE                                        = 1 shl 7,
    { When comparing strings for this value, compare with case sensitivity.
      By default, strings are compared with case sensitivity.
      If \ref CYAML_CFG_CASE_INSENSITIVE is set, this can override the
      configured behaviour for this specific value.
      \note If both \ref CYAML_FLAG_CASE_SENSITIVE and
      \ref CYAML_FLAG_CASE_INSENSITIVE are set, then case insensitive takes
      precedence.
      \note This applies to values of types \ref CYAML_MAPPING,
      \ref CYAML_ENUM, and \ref CYAML_FLAGS.  For mappings, it applies to
      matching of the mappings' keys.  For enums and flags it applies to the
      comparison of \ref cyaml_strval strings. }
    CYAML_FLAG_CASE_INSENSITIVE                                      1 shl 8
  );
  cyaml_flag_e = cyaml_flag;



{$IFDEF WINDOWS}
  const libYaml = 'libcyaml.dll';
{$ENDIF}
{$IFDEF LINUX}
  const libYaml = 'libcyaml.so';
{$ENDIF}



implementation

end.

