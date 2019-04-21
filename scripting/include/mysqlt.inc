#if defined _mysqlt_included
  #endinput
#endif
#define _mysqlt_included
#if AMXX_VERSION_NUM >= 175
 #pragma reqclass mysqlt
 #if !defined AMXMODX_NOAUTOLOAD
  #pragma defclasslib mysqlt mysqlt
 #endif
#endif

//#define OLDNATIVES_COMPACTIBILITY


#if !defined _sqlx_included
enum
{
	TQUERY_CONNECT_FAILED=-2,
	TQUERY_QUERY_FAILED=-1,
	TQUERY_SUCCESS=0,
};

enum Handle
{
   Empty_Handle
};

#endif

/*
[Configura la performance del ThreadsQuery]
 -collect_time:
   Tiempo en milisegundos en el que se recolectan los datos listos
 -th_think_time:
   Tiempo en milisegundos para el proximo frame del Thread
 -threads_per_frame:
   Cantidad de Threads simultaneamente
*/
native mysql_performance(collect_time=100, th_think_time=100, threads_per_frame=1);


/*
[Realiza una consulta]
 -cn_handler:
   El handler devuelto por mysql_makehost o mysql_connect.
 -handler:
   La funcion que sera llamada al finalizar la consulta
 -query:
   La consulta
 -data:
   Array para pasar algun dato a la funcion handler
 -datasize:
   Tamaño del array data
----------------------------------------------------------------------------------
La funcion handler tiene este formato:
*public query_handler(failstate, error[], errnum, data[], size, Float:queuetime)
 -failstate:
   Estado de la consulta:
      TQUERY_CONNECT_FAILED: Fallo la conexión
      TQUERY_QUERY_FAILED: Fallo la consulta
      TQUERY_SUCCESS: Todo OK :P
 -error:
   String del error
 -errnum:
   Codigo del error
 -data:
   Datos pasados desde mysql_query
 -size:
   Tamaño del array data
 -queuetime:
   Tiempo transcurrido desde que se creo la consulta hasta que finalizo
  
*/
native mysql_query(Handle:cn_handler, const handler[], const query[], const data[]="", datasize=0);

/*
[Crea un identificador a un Host]
 return: Devuelve el Handle de un Host
*/
native Handle:mysql_makehost(const host[], const user[], const pass[], const db[], timeout=0);

/*[Libera el Handle de un Host o de una Conexión]*/
native mysql_free(Handle:_handle);

/*
[Crea una conexión permanente con el servidor MySQL]
 return: Devuelve el Handle de la Conexión
*/
native Handle:mysql_connect(Handle:host_handler, &errcode, error[], maxlength);

/*
[Comprueba si hay mas resultados]
 return: Devuelve true si hay mas resultados,de lo contrario false
*/
native mysql_more_results();

/*
[Comprueba si una columna no tiene un valor]
 return: Devuelve true si no tiene un valor,de lo contrario false
*/
native mysql_isnull(column);

/*
[Obtiene los datos de una columna(ID)]
 -column:
   El id de la columna
   
 Ejemplo:
   -Para numeros:
       new num = mysql_read_result(0)
       
   -Para Float:
       new Float:num2
       mysql_read_result(1, num2)
   -Para String:
       new str[32]
       mysql_read_result(2, str, 31)
*/
native mysql_read_result(column, {Float,_}:...);

/*
[Obtiene los datos de una columna(Name)]
 -name:
   El nombre de la columna
   
 Ejemplo:
   -Para numeros:
       new num = mysql_read_result2("columna1")
       
   -Para Float:
       new Float:num2
       mysql_read_result2("columna2", num2)
   -Para String:
       new str[32]
       mysql_read_result2("columna3", str, 31)
*/
native mysql_read_result2(name[], {Float,_}:...);

/*[Avanza al siguiente resultado]*/
native mysql_next_row();

/*[Devuelve el numero de campos afectados]*/
native mysql_affected_rows();

/*[Devuelve el numero de resultados]*/
native mysql_num_results();

/*[Devuelve el numero de columnas]*/
native mysql_num_columns();

/*[Se obtiene el nombre de una columna]*/
native mysql_fieldnumtoname(num, name[], maxlength);

/*[Se obtiene el id de una columna]*/
native mysql_fieldnametonum(const name[]);

/*[Se obtiene el ID del autoincrement si se inserto un campo nuevo]*/
native mysql_get_insert_id();

/*[Se obtiene la consulta del ThreadsQuery]*/
native mysql_get_query(buffer[], maxlength);

/*[Vuelve atras un resultado]*/
native mysql_rewind();


native mysql_next_result_set();

native mysql_escape_string(buffer[], buflen, const string[]);
native mysql_escape_string2(buffer[], buflen, const fmt[], any:...);




#if !defined _sqlx_included && defined OLDNATIVES_COMPACTIBILITY
#define SQL_ThreadQuery	mysql_query
#define SQL_MakeDbTuple	mysql_makehost
#define SQL_FreeHandle	mysql_free
#define SQL_Connect	mysql_connect
stock SQL_MoreResults(Handle:query)
	mysql_more_results()
stock SQL_IsNull(Handle:query, column)
	mysql_isnull(column)
stock SQL_NextRow(Handle:query)
	mysql_next_row()
stock SQL_AffectedRows(Handle:query)
	mysql_affected_rows()
stock SQL_NumResults(Handle:query)
	mysql_num_results()
stock SQL_NumRows(Handle:query)
	mysql_num_results()
stock SQL_NumColumns(Handle:query)
	mysql_num_columns()
stock SQL_FieldNumToName(Handle:query, num, name[], maxlength)
	mysql_fieldnumtoname(num, name, maxlength)
stock SQL_FieldNameToNum(Handle:query, const name[])
	mysql_fieldnametonum(name)
stock SQL_GetInsertId(Handle:query)
	mysql_get_insert_id()
stock SQL_GetQueryString(Handle:query, buffer[], maxlength)
	mysql_get_query(buffer, maxlength)
stock SQL_Rewind(Handle:query)
	mysql_rewind()
stock SQL_NextResultSet(Handle:query)
	mysql_next_result_set()
stock SQL_QuoteString(Handle:db, buffer[], buflen, const string[])
	mysql_escape_string(buffer, buflen, string)
stock SQL_QuoteStringFmt(Handle:db, buffer[], buflen, const fmt[], any:...)
	set_fail_state("SQL_QuoteStringFmt: This function is deprecated")
stock SQL_ReadResult(Handle:query, column, {Float,_}:...)
{
	new args = numargs()

	if(args == 2) return mysql_read_result(column)
	if(args == 3)
	{
		new Float:value
		mysql_read_result(column, value)
		setarg(2, _, _:value)
		return 1
	}
	else {
		new string[512], len = getarg(3)
	
		mysql_read_result(column, string, 511)
		
		len = min(getarg(3), strlen(string))
		new cell
		while(cell < len)
		{
			if(!setarg(2, cell, string[cell])) break
			cell++
		}
		setarg(2, len, 0)
		return len
	}
	
	return 0
}
#endif
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang11274\\ f0\\ fs16 \n\\ par }
*/
