extends Node2D
class_name compresseur
const HuffManNode = preload("res://huffman/noeud_huffman.gd")
const CHUNK_SIZE = 65536 


func recup_frequences_streaming(path: String) -> Dictionary:
	var frequences : Dictionary = {}
	var file = FileAccess.open(path, FileAccess.READ)
	var rle_state = {"last_char": "", "count": 0}
	
	while not file.eof_reached():
		var chunk = file.get_buffer(CHUNK_SIZE)
		var text_rle = apply_rle_on_chunk(chunk, rle_state)
		for c in text_rle:
			frequences[c] = frequences.get(c, 0) + 1
	var final_rle = finalize_rle(rle_state)
	for c in final_rle:
		frequences[c] = frequences.get(c, 0) + 1
		
	file.close()
	return frequences

	
func creation_noeuds_initiaux(tableau_de_frequences:Dictionary)->Array[HuffManNode]:
	var noeuds:Array[HuffManNode]=[]
	for valeur in tableau_de_frequences.keys():
		var freq : int = tableau_de_frequences[valeur]
		var nouveau_noeud:HuffManNode=HuffManNode.new(freq,valeur)
		noeuds.append(nouveau_noeud)
	return noeuds
func _sorter_de_noeuds(a:HuffManNode,b:HuffManNode)->bool:
	return a.frequence<b.frequence
	
func construction_arbre_huffman(noeuds_initiaux:Array[NoeudHuffman])->HuffManNode:
	var noeuds_a_utiliser:Array[HuffManNode]=noeuds_initiaux.duplicate()
	while noeuds_a_utiliser.size()>1:
		noeuds_a_utiliser.sort_custom(_sorter_de_noeuds)
		var noeud_de_gauche : HuffManNode = noeuds_a_utiliser.pop_front()
		var noeud_de_droite : HuffManNode = noeuds_a_utiliser.pop_front()
		var nouvelle_frequence : int = noeud_de_gauche.frequence + noeud_de_droite.frequence
		var nouveau_noeud_parent : HuffManNode = HuffManNode.new(
			nouvelle_frequence,
			"",
			noeud_de_gauche,
			noeud_de_droite
		)
		noeuds_a_utiliser.append(nouveau_noeud_parent)
	if noeuds_a_utiliser.size()==1:
		return noeuds_a_utiliser[0]
	else : return null
	
func generation_de_code_recursive(noeud:HuffManNode,code_actuel:String,code_map:Dictionary):
	if noeud == null:
		return
	if noeud.contenu!="":
		code_map[noeud.contenu] = code_actuel
		return
	if noeud.noeud_de_gauche != null :
		generation_de_code_recursive(noeud.noeud_de_gauche,code_actuel+"0",code_map)
	if noeud.noeud_de_droite != null :
		generation_de_code_recursive(noeud.noeud_de_droite,code_actuel+"1",code_map)

func recup_huffman_code(noeud_racine : HuffManNode)->Dictionary:
	var codes:={}
	if noeud_racine != null :
		generation_de_code_recursive(noeud_racine,"",codes)
	return codes
	
func bit_string_to_bytes(bit_string: String) -> PackedByteArray:
	var bytes = PackedByteArray()
	var padding_needed = (8 - (bit_string.length() % 8)) % 8
	for i in range(padding_needed):
		bit_string += "0"
	for i in range(0, bit_string.length(), 8):
		var byte_str = bit_string.substr(i, 8)
		var byte_value = 0
		
		for j in range(8):
			if byte_str[j] == "1":
				byte_value += (1 << (7 - j))
		bytes.append(byte_value)    
	return bytes
	
func bit_string_to_bytes_partial(bit_string: String) -> Dictionary:
	var bytes = PackedByteArray()
	var full_bytes_len = (bit_string.length() / 8) * 8
	for i in range(0, full_bytes_len, 8):
		var byte_value = 0
		for j in range(8):
			if bit_string[i+j] == "1":
				byte_value += (1 << (7 - j))
		bytes.append(byte_value)
	return {
		"bytes": bytes,
		"remaining_bits": bit_string.substr(full_bytes_len)
	}
	
func apply_rle_on_chunk(chunk: PackedByteArray, state: Dictionary) -> String:
	var rle_result = ""
	var last_char = state.get("last_char", "")
	var count = state.get("count", 0)
	
	for i in range(chunk.size()):
		var c = char(chunk[i])
		if c == last_char and count < 999:
			count += 1
		else:
			if last_char != "":
				if count > 3:
					rle_result += "{" + str(count) + "}" + last_char
				else:
					for n in range(count):
						rle_result += last_char
			last_char = c
			count = 1
	
	state["last_char"] = last_char
	state["count"] = count
	return rle_result

func finalize_rle(state: Dictionary) -> String:
	if state.get("last_char", "") != "":
		return "{" + str(state["count"]) + "}" + state["last_char"]
	return ""
	
func compress_file_pipeline(input_path: String, output_path: String):
	var freq = recup_frequences_streaming(input_path)
	var tree = construction_arbre_huffman(creation_noeuds_initiaux(freq))
	var codes = recup_huffman_code(tree)
	
	var file_in = FileAccess.open(input_path, FileAccess.READ)
	var file_out = FileAccess.open(output_path, FileAccess.WRITE)
	
	if not file_in or not file_out: return
	file_out.store_var(freq)
	
	var total_size = file_in.get_length()
	var rle_state = {"last_char": "", "count": 0}
	var bit_buffer = "" 
	
	while not file_in.eof_reached():
		var chunk = file_in.get_buffer(CHUNK_SIZE)
		if chunk.is_empty(): break
		var text_rle = apply_rle_on_chunk(chunk, rle_state)
		
		for c in text_rle:
			if codes.has(c):
				bit_buffer += codes[c]
		
		if bit_buffer.length() >= 8:
			var bytes_to_write = bit_string_to_bytes_partial(bit_buffer) 
			file_out.store_buffer(bytes_to_write["bytes"])
			bit_buffer = bytes_to_write["remaining_bits"]
	var final_str = finalize_rle(rle_state)
	for c in final_str: bit_buffer += codes[c]
	
	if bit_buffer != "":
		file_out.store_buffer(bit_string_to_bytes(bit_buffer))
	
	file_in.close()
	file_out.close()
	await get_tree().process_frame


func decompress_with_header(input_path: String, output_path: String):
	var file_in = FileAccess.open(input_path, FileAccess.READ)
	if not file_in: return
	var freq = file_in.get_var()
	var tree = construction_arbre_huffman(creation_noeuds_initiaux(freq))
	var file_out = FileAccess.open(output_path, FileAccess.WRITE)
	var total_size = file_in.get_length()
	var current_node = tree
	var rle_buffer = ""
	
	while not file_in.eof_reached():
		var chunk = file_in.get_buffer(CHUNK_SIZE)
		for byte in chunk:
			for i in range(8):
				var bit = (byte >> (7 - i)) & 1
				current_node = current_node.noeud_de_gauche if bit == 0 else current_node.noeud_de_droite
				
				if current_node.noeud_de_gauche == null and current_node.noeud_de_droite == null:
					rle_buffer += current_node.contenu
					current_node = tree
					
					if rle_buffer.length() > 2048:
						file_out.store_string(decode_rle_string(rle_buffer)) 
						rle_buffer = ""
		
		await get_tree().process_frame

	if rle_buffer != "":
		file_out.store_string(decode_rle_string(rle_buffer))
	
	file_in.close()
	file_out.close()
	

func decode_rle_string(rle_text: String) -> String:
	var result = ""
	var i = 0
	while i < rle_text.length():
		if rle_text[i] == "{":
			var start_pos = i
			i += 1
			var count_str = ""
			while i < rle_text.length() and rle_text[i] != "}":
				count_str += rle_text[i]
				i += 1
			
			if i < rle_text.length() and rle_text[i] == "}":
				i += 1 # saute }
				if i < rle_text.length():
					var count = count_str.to_int()
					var character = rle_text[i]
					for n in range(count):
						result += character
					i += 1
				else: result += "{" + count_str + "}"
			else:
				result += "{" + count_str 
		else:
			result += rle_text[i]
			i += 1
	return result
