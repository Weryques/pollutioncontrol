/**
* Name: PollutionControlSimulation
* Author: 
* Description: 
* Tags: 
*/

model PollutionControlSimulation

/*
 * 1 Agentes: 
 * 
 * Veículos:
 * Objetivo: Percorrer as rodovias da cidade, Emitir poluição no Ar.
 * Capacidades - Percepção+Ação: Perceber outros veículos e desviar deles; Perceber sentido correto e velocidade máxima das vias;
 * 
 * 2 Ambiente:
 * 
 * Variáveis: Velocidade das vias da cidade, quantidade veiculos.
 * 
 * 3 Comunicação: há apenas um tipo de agente, sem necessidade de comunicação.
 * 
 * 4 O modelo tem o objetivo de: Representar um ambiente onde temos 1 tipo de agente poluente e como as alterações no agente influenciam sua capacidade de poluir.
 */

global {   
	file shape_file_roads  <- file("../includes/roads.shp"); //Importação do arquivo com vias
	file shape_file_nodes  <- file("../includes/nodes.shp"); //Importação do arquivo com semáforos e stops
	geometry shape <- envelope(shape_file_roads); // Limites do ambiente
	
	graph road_network; // Gráfico para rede de vias
	int nb_car <- 2409; // Número de carros
	float speedm <- 30 °km/°h; // Velocidade mínima
	float pollution_coeff <- 0.0; // Coeficiente de poluição
	float pollution_stoped <- 0.0; // Poluição parado
	float kilo <- 0.0; // Total de km percorridos
	float speedex <- 0.0; // Velocidade assumida no momento
	float pollution_filter <- 0.0; // Poluição com filtro
	
	init {  
		// Cria semáforo a partir do arquivo
		create semaphore from: shape_file_nodes with:[is_traffic_signal::(read("type") = "traffic_signals")];
		ask semaphore where each.is_traffic_signal {
			// Define se o semáforo será criado fechado ou aberto
			stop << flip(0.5) ? roads_in : [] ;
		}
		
		// Cria vias a partir do arquivo
		create road from: shape_file_roads with:[lanes::int(read("lanes")), maxspeed::float(read("maxspeed")) °km/°h, oneway::string(read("oneway"))] {
			geom_display <- (shape + (2.5 * lanes));
			switch oneway {
				match "no" {
					create road {
						lanes <- myself.lanes; // Adiciona faixas do shapefile
						shape <- polyline(reverse(myself.shape.points)); // Pega lista de coordenadas que delimitam o ambiente
						maxspeed <- myself.maxspeed; // Adiciona a velocidade máxima do shapefile
						geom_display  <- myself.geom_display;
						linked_road <- myself;
						myself.linked_road <- self;
					}
				}
				match "-1" {
					shape <- polyline(reverse(shape.points)); // Pega lista de coordenadas que delimitam o ambiente
				}
			}
		}	
		
		map general_speed_map <- road as_map(each::( each.shape.perimeter / (each.maxspeed) ));
		// Cria um gráfico a partir da lista de arestas do map acima conectando as vias (arestas) ao vértices (semáforos) com os pesos das velocidades
		road_network <- (as_driving_graph(road, semaphore)) with_weights general_speed_map;
				
		create car number: nb_car { 
			speed <- speedm; // Inicializa com velocidade miníma
			real_speed <- speedm; // Idem
			vehicle_length <- 3.0 °m; // Tamanho do veículo em metros
			right_side_driving <- true; // Direção do lado direito
			proba_lane_change_up <- 0.1 + (rnd(500) / 500); // Probabilidade de mudar de faixa para a da esquerda
			proba_lane_change_down <- 0.5+ (rnd(500) / 500); // Probabilidade de muda de faixa para a da direita
			location <- one_of(semaphore where empty(each.stop)).location; // Localizado inicialmente onde não tem semáforo fechado
			security_distance_coeff <- 2 * (1.5 - rnd(1000) / 1000); // Distância segura do veiculo da frente
			proba_respect_priorities <- 1.0 - rnd(200/1000); // Probabilidade de respeitar prioridades
			proba_respect_stops <- [1.0 - rnd(2) / 1000]; // Probabilidade respeitar Pares
			proba_block_node <- rnd(3) / 1000; // Probabilida de bloquear um cruzamento para entre numa nova rua
			proba_use_linked_road <- 0.0; // Probabilidade de pegar rua em sentido reverso (se houver)
			max_acceleration <- 0.5 + rnd(500) / 1000; // Aceleração máxima
			speed_coeff <- 1.2 - (rnd(400) / 1000); // coeficiente de velocidade
		}
	}
	
	// Simplesmente pausa a simulação no ciclo 420
	reflex end when: cycle = 420 {
		do pause;
	}
} 
species semaphore skills: [skill_road_node] {
	bool is_traffic_signal;
	int time_to_change <- 100; // Tempo para mudar do vermelho para verde e vice e versa
	int counter <- rnd (time_to_change); // Inicializado com um valor de 0 a 100. Counter é o número de passos desde a ultima mudança de cor
	
	// Define a condição de mudança de cor do semáforo
	reflex dynamic when: is_traffic_signal {
		counter <- counter + 1; // Incrementa os passos de 1 em 1
		if (counter >= time_to_change) { // Se o número de passos é igual ao tempo de mudança. O semáforo muda da cor que está no momento para a outra
			counter <- 0; // Contador é zerado
			stop[0] <- empty (stop[0]) ? roads_in : []; // O valor de stop é trocado
			//Se o semáforo estava verde stop é alterado para a lista de ruas bloqueadas roads_in (semáforo fica vermelho)
			//Se o semáforo estava vermelho stop é alterado para lista vazia [] (semáforo fica verde)
		} 
	}
	
	// Define a aparência do semáforo
	aspect geom3D {
		if (is_traffic_signal) { // Confirma se é um semáforo	
			draw box(1,1,10) color:rgb("black"); // Desenha uma caixa (o poste do semáforo)
			draw sphere(5) at: {location.x,location.y,12} color: empty (stop[0]) ? #green : #red; // Desenha uma esfera (o semáforo)
		}
	}
}
// Skill road faz parte do modelo definido por Taillandier
species road skills: [skill_road] { 
	string oneway;
	geometry geom_display;
	aspect geom {    
		draw geom_display color: #gray;
	}  
}
// Advanced Driving é o modelo definido por Taillandier
species car skills: [advanced_driving] { 
	rgb color <- rnd_color(255); // O carro terá cores aleatórias, RGB de 0 a 255
	
	reflex time_to_go when: final_target = nil {
		current_path <- compute_path(graph: road_network, target: one_of(semaphore)); // Calcula o caminho para o semaforo com base na rede de vias
	}

	reflex move when: final_target != nil {
		do drive; // Leva o veiculo até o seu alvo final, o semáforo
		
		list segments <- current_path.segments;
		loop line over: segments{
			float distance <- line.perimeter; // O tamanho do contorno da geometria line (rua)
			
			if(speedex >= 10.0 and speedex <= 50.0){
				// Calculo de toda a poluição gerada
				pollution_coeff <- pollution_coeff + (((rnd(1.3, 1.5) * distance) / 1000000) / 100); // As divisões são para se adequar à escala do gráfico
				// Calculo da poluição com filtro
				pollution_filter <- pollution_filter + (((rnd(0.2, 0.244) * distance) / 1000000) / 100); // As divisões são para se adequar à escala do gráfico
			}
			else if(speedex > 50.0 and speedex <= 70.0){
				pollution_coeff <- pollution_coeff + (((rnd(1.51, 1.7) * distance) / 1000000) / 100); // As divisões são para se adequar à escala do gráfico
				pollution_filter <- pollution_filter + (((rnd(0.2, 0.224) * distance) / 1000000) / 100); // As divisões são para se adequar à escala do gráfico
			}
			else if(speedex > 70.0 and speedex <= 90.0){
				pollution_coeff <- pollution_coeff + (((rnd(1.71, 1.9) * distance) / 1000000) / 100); // As divisões são para se adequar à escala do gráfico
				pollution_filter <- pollution_filter + (((rnd(0.2, 0.224) * distance) / 1000000) / 100); // As divisões são para se adequar à escala do gráfico
			}
			else if(speedex > 90.0){
				pollution_coeff <- pollution_coeff + (((rnd(1.91, 2.0) * distance) / 1000000) / 100); // As divisões são para se adequa à escala do gráfico
				pollution_filter <- pollution_filter + (((rnd(0.2, 0.224) * distance) / 1000000) / 100); // As divisões são para se adequar à escala do gráfico
			}
			else{
				// Calculo da poluição do carro parado.
				pollution_stoped <- pollution_stoped + (rnd(0.1, 0.8) / 100000) / 100; // As divisões são para se adequar à escala do gráfico
			}			
			// Soma de todas as distânias percorridas
			kilo <- kilo + (distance / 100000); // A divisão é para se adequar à escala do gráfico	
			
		}
		
		// A velocidade do carro é influenciada pela velocidade máxima, pela velocidade real, pela aceleração máxima e pelo coeficiente de velocidade.
		speedex <- min([max_speed, min([real_speed + max_acceleration, max_speed * speed_coeff])]) * 10; // A multiplicação é para se adequar à escala do gráfico
	}
	
	aspect car3D {
		if (current_road) != nil {
			point loc <- calcul_loc();
			// O carro é desenhado na coordenada retornada 'at: loc'
			draw box(vehicle_length, 1,1) at: loc rotate:  heading color: color;
			draw triangle(0.5) depth: 1.5 at: loc rotate:  heading + 90 color: color;	
		}
	} 
	
	// Calcula a localização e retorna um point com as coordenadas x e y:
	point calcul_loc {
		float val <- (road(current_road).lanes - current_lane) + 0.5;
		val <- on_linked_road ? val * - 1 : val;
		if (val = 0) {
			return location;
		} else {
			return (location + {cos(heading + 90) * val, sin(heading + 90) * val});
		}
	}
}

experiment pollution_control_simulation type: gui { // Criação da GUI
	// Criação dos formulários para alterar variáveis
	parameter "Número de carros:" var: nb_car category: "Carros";
	parameter "Velocidade mínima m/s:" var: speedm category: "Carros";
	
	float minimum_cycle_duration <- 0.2; // O esperimento roda 80% mais rápido
	
	// Definição do que será exibido na GUI
	output {
		// Display que mostra o mapa das vias
		display city type: opengl{
			// Adição das espécies  com seus apectos definidos acima
			species road aspect: geom refresh: false;
			species semaphore aspect: geom3D;
			species car aspect: car3D;
		}
		
		// Display que mostra os gráficos
		display charts{
			chart "Quilos de poluicão de todos os carros" type: histogram size:{0.5, 0.5} position:{0,0}{ // Os atributos do gráfico
				data "Poluição sem filtro" value: pollution_coeff color: #red marker: false; // Adição da variável com soma da poluição dirigindo sem filtro
				data "Poluição parado sem filtro" value: pollution_stoped color: #blue marker: false; // Adição da variável com soma da poluição parado
				data "Poluição com filtro" value: pollution_filter color: #teal marker: false; // Adição da variável com soma da poluição com filtro
				data "Máximo de poluição" value: 10 color: #gray marker: false; // Eixo y do gráfico
			}
			chart "Distância percorrida de todos os carros" type: series size:{0.5, 0.5} position:{0.5,0}{
				data "Km percorridos" value: kilo color: #blue marker: false; // Adição da variável com soma dos km percorridos
				data "Distância Máxima" value: 10000 color: #black marker: false; // y
			}
			chart "Velocidade" type: series size:{1, 0.5} position:{0,0.5}{
				data "Velocidade" value: speedex color:#goldenrod marker: false; // Adição da variável com a velocidade do momento
				data "Velocidade Máxima" value: 120 color:#darkorange marker: false; // y
			}
		}
	}
}