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
    CYAML_FLAG_POINTER_NULL          = (1 shl 2) or Longint(CYAML_FLAG_POINTER),
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
    CYAML_FLAG_POINTER_NULL_STR = (1 shl 3) or Longint(CYAML_FLAG_POINTER_NULL),
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
    CYAML_FLAG_CASE_INSENSITIVE                                      = 1 shl 8
  );
  cyaml_flag_e = cyaml_flag;

  { Mapping between a string and a signed value.
    Used for \ref CYAML_ENUM and \ref CYAML_FLAGS types. }
  pcyaml_strval = ^cyaml_strval;
  cyaml_strval = record
    str : PChar;                   { String representing enum or flag value. }
    val : QWord;                   { Value of given string. }
  end;
  cyaml_strval_t = cyaml_strval;

  { Bitfield value info.
    Used for \ref CYAML_BITFIELD type. }
  pcyaml_bitdef = ^cyaml_bitdef;
  cyaml_bitdef = record
    name : PChar;                  { String representing the value's name. }
    offset : Byte;                 { Bit offset to value in bitfield. }
    bits : Byte;                   { Maximum bits available for value. }
  end;
  cyaml_bitdef_t = cyaml_bitdef;

  pcyaml_schema_field = ^cyaml_schema_field;

  { Schema definition for a value.
    \note There are convenience macros for each of the types to assist in
          building a CYAML schema data structure for your YAML documents.

    This is the fundamental building block of CYAML schemas.  The load, save and
    free functions take parameters of this type to explain what the top-level
    type of the YAML document should be.

    Values of type \ref CYAML_SEQUENCE and \ref CYAML_SEQUENCE_FIXED contain a
    reference to another \ref cyaml_schema_value representing the type of the
    entries of the sequence.  For example, if you want a sequence of integers,
    you'd have a \ref cyaml_schema_value for the for the sequence value type,
    and another for the integer value type.

    Values of type \ref CYAML_MAPPING contain an array of
    \ref cyaml_schema_field entries, defining the YAML keys allowed by the
    mapping.  Each field contains a \ref cyaml_schema_value representing the
    schema for the value. }
  pcyaml_schema_value = ^cyaml_schema_value;
  cyaml_schema_value = record
    value_type : cyaml_type;       { The type of the value defined by this
                                     schema entry. }
    flags : cyaml_flag;            { Flags indicating value's characteristics. }
    { Size of the value's client data type in bytes.
      For example, `short` `int`, `long`, `int8_t`, etc are all signed integer
      types, so they would have the type \ref CYAML_INT, however, they have
      different sizes. }
    data_size : Cardinal;
    case Integer of                { Anonymous union containing type-specific
                                     attributes. }
      1 : (
        { \ref CYAML_STRING type-specific schema data. }
        string_schema : record
          { Minimum string length (bytes).
            \note Excludes trailing NUL. }
          min : Cardinal;
          { Maximum string length (bytes).
            \note Excludes trailing NULL, so for character array
		  strings (rather than pointer strings), this
		  must be no more than `data_size - 1`. }
          max : Cardinal;
        end;
      );
      2 : (
        { \ref CYAML_MAPPING type-specific schema data. }
        mapping : record
          { Array of cyaml mapping field schema definitions.
            The array must be terminated by an entry with a NULL key.  See
            \ref cyaml_schema_field_t and \ref CYAML_FIELD_END for more info. }
          fields : pcyaml_schema_field;
        end;
      );
      3 : (
        { \ref CYAML_BITFIELD type-specific schema data. }
        bitfields : record
          { Array of bit definitions for the bitfield. }
          bitdefs : pcyaml_bitdef;
          { Entry count for bitdefs array. }
          count : Cardinal;
        end;
      );
      4 : (
        { \ref CYAML_SEQUENCE and \ref CYAML_SEQUENCE_FIXED type-specific schema
          data. }
        sequence : record
          { Schema definition for the type of the entries in the
	    sequence.
            All of a sequence's entries must be of the same type, and a sequence
            can not have an entry type of type \ref CYAML_SEQUENCE (although
            \ref CYAML_SEQUENCE_FIXED is allowed).  That is, you can't have a
            sequence of variable-length sequences. }
          entry : pcyaml_schema_value;
          { Minimum number of sequence entries.
            \note min and max must be the same for \ref CYAML_SEQUENCE_FIXED. }
          min : Cardinal;
          { Maximum number of sequence entries.
            \note min and max must be the same for \ref CYAML_SEQUENCE_FIXED. }
          max : Cardinal;
        end;
      );
      5 : (
        { \ref CYAML_ENUM and \ref CYAML_FLAGS type-specific schema data. }
        enumeration : record
          { Array of string / value mappings defining enum. }
          strings : pcyaml_strval;
          { Entry count for strings array. }
          count : Cardinal;
        end;
      );
  end;
  cyaml_schema_value_t = cyaml_schema_value;

  { Schema definition entry for mapping fields.

    YAML mappings are key:value pairs.  CYAML only supports scalar mapping keys,
    i.e. the keys must be strings.  Each mapping field schema contains a
    \ref cyaml_schema_value to define field's value.

    The schema for mappings is composed of an array of entries of this data
    structure.  It specifies the name of the key, and the type of the value. It
    also specifies the offset into the data at which value data should be
    placed. The array is terminated by an entry with a NULL key. }
  cyaml_schema_field = record
    { String for YAML mapping key that his schema entry describes, or NULL to
      indicated the end of an array of \ref cyaml_schema_field entries. }
    key : PChar;
    { Offset in data structure at which the value for this key should be
      placed / read from. }
    data_offset : Cardinal;
    { \ref CYAML_SEQUENCE only: Offset to sequence entry count member in
      mapping's data structure. }
    count_offset : Cardinal;
    { \ref CYAML_SEQUENCE only: Size in bytes of sequence entry count member in
      mapping's data structure. }
    count_size : Byte;
    { Defines the schema for the mapping field's value. }
    value : cyaml_schema_value;
  end;
  cyaml_schema_field_t = cyaml_schema_field;

  { CYAML behavioural configuration flags for clients
    These may be bitwise-ORed together. }
  cyaml_cfg_flags = (
    { This indicates CYAML's default behaviour. }
    CYAML_CFG_DEFAULT                                                = 0,
    { When set, unknown mapping keys are ignored when loading YAML. Without this
      flag set, CYAML's default behaviour is to return with the error
      \ref CYAML_ERR_INVALID_KEY. }
    CYAML_CFG_IGNORE_UNKNOWN_KEYS                                    = 1 shl 0,
    { When saving, emit mapping / sequence values in block style.
      This setting can be overridden for specific values using schema value
      flags (\ref cyaml_flag).
      \note This only applies to values of type \ref CYAML_MAPPING,
      \ref CYAML_SEQUENCE, or \ref CYAML_SEQUENCE_FIXED.
      \note If both \ref CYAML_CFG_STYLE_BLOCK and \ref CYAML_CFG_STYLE_FLOW are
      set, then block style takes precedence. }
    CYAML_CFG_STYLE_BLOCK                                            = 1 shl 1,
    { When saving, emit mapping / sequence values in flow style.
      This setting can be overridden for specific values using schema value
      flags (\ref cyaml_flag).
      \note This only applies to values of type \ref CYAML_MAPPING,
      \ref CYAML_SEQUENCE, or \ref CYAML_SEQUENCE_FIXED.
      \note If both \ref CYAML_CFG_STYLE_BLOCK and \ref CYAML_CFG_STYLE_FLOW are
      set, then block style takes precedence. }
    CYAML_CFG_STYLE_FLOW                                             = 1 shl 2,
    { When saving, emit "---" at document start and "..." at document end.
      If this flag isn't set, these document delimiting marks will not be
      emitted. }
    CYAML_CFG_DOCUMENT_DELIM                                         = 1 shl 3,
    { When comparing strings, compare without case sensitivity.
      By default, strings are compared with case sensitivity. }
    CYAML_CFG_CASE_INSENSITIVE                                       = 1 shl 4,
    { When loading, don't allow YAML aliases in the document.
      If this option is enabled, anchors will be ignored, and the error code
      \ref CYAML_ERR_ALIAS will be returned if an alias is encountered.
      Setting this removes the overhead of recording anchors, so it may be worth
      setting if aliases are not required, and memory is constrained. }
    CYAML_CFG_NO_ALIAS                                               = 1 shl 5
  );
  cyaml_cfg_flag_t = cyaml_cfg_flags;

  { CYAML function return codes indicating success or reason for failure.
    Use \ref cyaml_strerror() to convert an error code to a human-readable
    string. }
  cyaml_err = (
    CYAML_OK,                      { Success. }
    CYAML_ERR_OOM,                 { Memory allocation failed. }
    CYAML_ERR_ALIAS,               { See \ref CYAML_CFG_NO_ALIAS. }
    CYAML_ERR_FILE_OPEN,           { Failed to open file. }
    CYAML_ERR_INVALID_KEY,         { Mapping key rejected by schema. }
    CYAML_ERR_INVALID_VALUE,       { Value rejected by schema. }
    CYAML_ERR_INVALID_ALIAS,       { No anchor found for alias. }
    CYAML_ERR_INTERNAL_ERROR,      { Internal error in LibCYAML. }
    CYAML_ERR_UNEXPECTED_EVENT,    { YAML event rejected by schema. }
    CYAML_ERR_STRING_LENGTH_MIN,   { String length too short. }
    CYAML_ERR_STRING_LENGTH_MAX,   { String length too long. }
    CYAML_ERR_INVALID_DATA_SIZE,   { Value's data size unsupported. }
    CYAML_ERR_TOP_LEVEL_NON_PTR,   { Top level type must be pointer. }
    CYAML_ERR_BAD_TYPE_IN_SCHEMA,  { Schema contains invalid type. }
    CYAML_ERR_BAD_MIN_MAX_SCHEMA,  { Schema minimum exceeds maximum. }
    CYAML_ERR_BAD_PARAM_SEQ_COUNT, { Bad seq_count param for schema. }
    CYAML_ERR_BAD_PARAM_NULL_DATA, { Client gave NULL data argument. }
    CYAML_ERR_BAD_BITVAL_IN_SCHEMA,{ Bit value beyond bitfield size. }
    CYAML_ERR_SEQUENCE_ENTRIES_MIN,{ Too few sequence entries. }
    CYAML_ERR_SEQUENCE_ENTRIES_MAX,{ Too many sequence entries. }
    CYAML_ERR_SEQUENCE_FIXED_COUNT,{ Mismatch between min and max. }
    CYAML_ERR_SEQUENCE_IN_SEQUENCE,{ Non-fixed sequence in sequence. }
    CYAML_ERR_MAPPING_FIELD_MISSING, { Required mapping field missing. }
    CYAML_ERR_BAD_CONFIG_NULL_MEMFN, { Client gave NULL mem function. }
    CYAML_ERR_BAD_PARAM_NULL_CONFIG, { Client gave NULL config arg. }
    CYAML_ERR_BAD_PARAM_NULL_SCHEMA, { Client gave NULL schema arg. }
    CYAML_ERR_LIBYAML_EMITTER_INIT,{ Failed to initialise libyaml. }
    CYAML_ERR_LIBYAML_PARSER_INIT, { Failed to initialise libyaml. }
    CYAML_ERR_LIBYAML_EVENT_INIT,  { Failed to initialise libyaml. }
    CYAML_ERR_LIBYAML_EMITTER,     { Error inside libyaml emitter. }
    CYAML_ERR_LIBYAML_PARSER,      { Error inside libyaml parser. }

    { This is **not a valid return code** itself. }
    CYAML_ERR__COUNT               { Count of CYAML return codes. }
  );
  cyaml_err_t = cyaml_err;

{$IFDEF WINDOWS}
  const libYaml = 'libcyaml.dll';
{$ENDIF}
{$IFDEF LINUX}
  const libYaml = 'libcyaml.so';
{$ENDIF}




implementation

end.

