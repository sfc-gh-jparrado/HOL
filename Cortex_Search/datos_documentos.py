"""
Datos estructurados para todos los documentos PDF
"""

# Datos para todos los documentos
DOCUMENTOS = {
    "esquis_carver": {
        "titulo": "Guía de Especificaciones",
        "subtitulo": "Esquís Carver Pro Series",
        "contenido": {
            "descripcion": "Los Esquís Carver Pro Series están diseñados para esquiadores avanzados que buscan precisión y control en pistas preparadas. Fabricados con tecnología de punta y materiales de alta calidad.",
            "modelos": [
                {"modelo": "Carver Pro 170", "longitud": "170 cm", "nivel": "Intermedio-Avanzado", "peso": "60-75 kg", "precio": "749 €"},
                {"modelo": "Carver Pro 180", "longitud": "180 cm", "nivel": "Avanzado-Experto", "peso": "70-85 kg", "precio": "799 €"},
                {"modelo": "Carver Pro 190", "longitud": "190 cm", "nivel": "Experto", "peso": "80-95 kg", "precio": "849 €"},
            ],
            "construccion": [
                "Núcleo: Madera de álamo y haya laminada con fibra de carbono",
                "Base: Base sinterizada P-Tex 4000 para máxima velocidad",
                "Cantos: Acero templado de 2.5mm para mayor durabilidad",
                "Laminado superior: Fibra de vidrio triaxial"
            ],
            "geometria": {
                "radio_giro": ["14.5 m", "16.2 m", "18.0 m"],
                "espátula": ["128 mm"] * 3,
                "patín": ["75 mm"] * 3,
                "cola": ["115 mm"] * 3
            },
            "rendimiento": {
                "optimo": "Nieve compactada y pistas preparadas",
                "bueno": "Nieve dura y hielo",
                "limitado": "Nieve profunda y fuera de pista"
            },
            "mantenimiento": {
                "afilado": "Cada 5-7 días de uso (88° base, 1° lateral)",
                "encerado": "Cada 3-4 días de uso (140-150°C)"
            },
            "garantia": "2 años contra defectos de fabricación",
            "contacto": {
                "email": "soporte@carver-skis.com",
                "telefono": "+34 900 123 456",
                "web": "www.carver-skis.com"
            }
        }
    },
    
    "esquis_racingfast": {
        "titulo": "Guía de Especificaciones",
        "subtitulo": "Esquís RacingFast Competition",
        "contenido": {
            "descripcion": "Los Esquís RacingFast Competition están diseñados específicamente para competición de slalom y slalom gigante. Ofrecen la máxima precisión, agarre y respuesta para esquiadores de alto rendimiento.",
            "modelos": [
                {"modelo": "RacingFast SL 165", "longitud": "165 cm", "tipo": "Slalom", "peso": "55-75 kg", "precio": "1.299 €"},
                {"modelo": "RacingFast SL 170", "longitud": "170 cm", "tipo": "Slalom", "peso": "65-85 kg", "precio": "1.299 €"},
                {"modelo": "RacingFast GS 185", "longitud": "185 cm", "tipo": "Slalom Gigante", "peso": "70-90 kg", "precio": "1.399 €"},
                {"modelo": "RacingFast GS 195", "longitud": "195 cm", "tipo": "Slalom Gigante", "peso": "80-100 kg", "precio": "1.399 €"},
            ],
            "construccion": [
                "Núcleo: Madera de fresno con láminas de titanal multicapa",
                "Base: Base sinterizada grafito de competición",
                "Cantos: Acero inoxidable de alta resistencia 3mm",
                "Laminado superior: Fibra de carbono unidireccional",
                "Placa de competición: Incluida (FIS homologado)"
            ],
            "rendimiento": {
                "nivel": "Experto / Competidor",
                "optimo": "Nieve dura, compactada, hielo",
                "certificacion": "Homologados FIS para competiciones"
            },
            "mantenimiento": {
                "afilado": "Antes de cada entrenamiento/carrera (87-88°)",
                "encerado": "Antes de cada sesión (cera fluorada)",
                "estructura": "Renovar cada 20-30 días de esquí"
            },
            "garantia": "1 año (producto de competición)",
            "contacto": {
                "email": "racing@racingfast.com",
                "telefono": "+34 900 234 567",
                "web": "www.racingfast.com"
            }
        }
    },
    
    "esquis_outpiste": {
        "titulo": "Guía de Especificaciones",
        "subtitulo": "Esquís OutPiste Freeride Series",
        "contenido": {
            "descripcion": "Los Esquís OutPiste Freeride Series están diseñados para aventureros que buscan conquistar la montaña fuera de las pistas preparadas. Perfectos para nieve profunda, terreno variado y esquí de travesía ligera.",
            "modelos": [
                {"modelo": "OutPiste Free 115", "longitud": "175-195 cm", "patín": "115 mm", "uso": "All-mountain freeride", "precio": "649 €"},
                {"modelo": "OutPiste Powder 125", "longitud": "180-190 cm", "patín": "125 mm", "uso": "Nieve profunda", "precio": "699 €"},
                {"modelo": "OutPiste Touring 105", "longitud": "170-180 cm", "patín": "105 mm", "uso": "Touring/freeride", "precio": "749 €"},
            ],
            "construccion": [
                "Núcleo: Madera de paulownia ultraligera con refuerzos de carbono",
                "Base: Base sinterizada grafito para bajo mantenimiento",
                "Cantos: Acero inoxidable 2.2mm",
                "Perfil: Rocker-Camber-Rocker (Free y Touring) / Full Rocker (Powder)",
                "Peso: 1.450-1.950g por esquí según modelo"
            ],
            "rendimiento": {
                "nivel": "Intermedio-Avanzado a Experto",
                "optimo": "Nieve fuera de pista, powder, touring",
                "bueno": "Nieve variada, pistas preparadas"
            },
            "seguridad": [
                "⚠️ Equipo obligatorio: ARVA, pala, sonda",
                "⚠️ Formación: Curso de seguridad en avalanchas requerido",
                "⚠️ Nunca esquiar solo en backcountry"
            ],
            "mantenimiento": {
                "afilado": "Cada 6-8 días de uso (88-89°)",
                "encerado": "Cada 5-6 días de uso",
                "nota": "Desafilar espátula y cola (últimos 10cm)"
            },
            "garantia": "2 años contra defectos de fabricación",
            "contacto": {
                "email": "info@outpiste.com",
                "telefono": "+34 900 345 678",
                "web": "www.outpiste.com"
            }
        }
    },
    
    "bicicleta_premium": {
        "titulo": "Guía de Usuario",
        "subtitulo": "Bicicleta Premium Road Master 3000",
        "contenido": {
            "descripcion": "Gracias por elegir la Bicicleta Premium Road Master 3000. Este manual te ayudará a conocer, mantener y disfrutar al máximo de tu nueva bicicleta de carretera de alto rendimiento.",
            "especificaciones": {
                "cuadro": "Aluminio 6061-T6 hydroformed, geometría racing",
                "tallas": "XS (48cm), S (52cm), M (56cm), L (58cm), XL (61cm)",
                "horquilla": "Carbono full monocoque",
                "peso": "9.2 kg (talla M, sin pedales)",
                "grupo": "Shimano 105 R7000 (11 velocidades)",
                "cassette": "11-30T",
                "platos": "50/34T (compacto)",
                "frenos": "Shimano 105 R7000 dual pivot",
                "ruedas": "Llantas de aleación doble pared, 28\"",
                "neumáticos": "Continental Ultra Sport 700x25C"
            },
            "presion_neumaticos": [
                {"peso": "< 60 kg", "presion": "90-95 PSI"},
                {"peso": "60-75 kg", "presion": "95-105 PSI"},
                {"peso": "75-90 kg", "presion": "105-115 PSI"},
                {"peso": "> 90 kg", "presion": "115-120 PSI"}
            ],
            "mantenimiento": {
                "diario": "Limpiar cuadro, remover barro, secar cadena",
                "semanal": "Limpiar y lubricar cadena, verificar presión",
                "mensual": "Limpieza profunda, verificar elongación de cadena, centrado de ruedas"
            },
            "garantia": {
                "cuadro": "5 años contra defectos de fabricación",
                "componentes": "2 años contra defectos de fabricación",
                "ruedas": "1 año"
            },
            "precio": "Desde 1.299 €",
            "contacto": {
                "web": "www.roadmaster.com",
                "email": "soporte@roadmaster.com",
                "telefono": "+34 900 456 789"
            }
        }
    },
    
    "bicicleta_xtreme": {
        "titulo": "Guía Técnica",
        "subtitulo": "Bicicleta Xtreme Road Bike 105 SL",
        "contenido": {
            "descripcion": "La Xtreme Road Bike 105 SL es una bicicleta de carretera de alto rendimiento diseñada para ciclistas competitivos y entusiastas avanzados. Combina un cuadro de carbono ultraligero con componentes Shimano 105.",
            "especificaciones": {
                "cuadro": "Carbono T800 UD monocoque",
                "peso_cuadro": "950g (talla M)",
                "horquilla": "Carbono T800 full monocoque (370g)",
                "grupo": "Shimano 105 R7000 (2x11 velocidades)",
                "peso_total": "7.8 kg (talla M, sin pedales)",
                "ruedas": "Xtreme Carbon Aero 40 (1.580g el par)",
                "neumáticos": "Continental Grand Prix 5000 700x25C"
            },
            "tallas": [
                {"talla": "XS", "altura_tubo": "480 mm", "estatura": "160-170 cm", "peso": "7.4 kg"},
                {"talla": "S", "altura_tubo": "510 mm", "estatura": "168-178 cm", "peso": "7.6 kg"},
                {"talla": "M", "altura_tubo": "540 mm", "estatura": "176-186 cm", "peso": "7.8 kg"},
                {"talla": "L", "altura_tubo": "560 mm", "estatura": "184-194 cm", "peso": "8.0 kg"},
            ],
            "mantenimiento": {
                "cadena": "Cambiar cada 3.000-5.000 km",
                "zapatas": "Cambiar si surco < 1mm",
                "neumáticos": "Cambiar si banda < 1mm",
                "cables": "Cambiar cada 10.000-15.000 km"
            },
            "garantia": {
                "cuadro": "5 años (carbono)",
                "componentes": "2 años"
            },
            "precio": "3.299 €",
            "contacto": {
                "web": "www.xtremebikes.com",
                "email": "soporte@xtremebikes.com",
                "telefono": "+34 900 567 890"
            }
        }
    },
    
    "bicicleta_downhill": {
        "titulo": "Especificaciones y Guía de Uso",
        "subtitulo": "Bicicleta Ultimate Downhill",
        "contenido": {
            "descripcion": "La Ultimate Downhill es una bicicleta de descenso extremo diseñada para los riders más exigentes. Con 200mm de recorrido, cuadro de aluminio reforzado y componentes de alta gama.",
            "especificaciones": {
                "cuadro": "Aluminio 7005-T6 triple butted",
                "suspensión_trasera": "200mm, DW-Link con RockShox Super Deluxe Ultimate",
                "horquilla": "RockShox BoXXer Ultimate, 200mm, 38mm stanchions",
                "grupo": "SRAM X01 DH (7 velocidades)",
                "frenos": "SRAM Code RSC hidráulicos, 4 pistones (220mm/200mm)",
                "ruedas": "DH aluminio 27.5\" con Maxxis Minion DHF/DHR II 2.5\"",
                "peso": "18.5 kg (talla M)"
            },
            "setup_suspension": [
                {"peso": "60-70 kg", "horquilla": "85-95 PSI", "amortiguador": "200-220 PSI"},
                {"peso": "70-80 kg", "horquilla": "95-105 PSI", "amortiguador": "220-240 PSI"},
                {"peso": "80-90 kg", "horquilla": "105-115 PSI", "amortiguador": "240-260 PSI"},
                {"peso": "90-100 kg", "horquilla": "115-125 PSI", "amortiguador": "260-280 PSI"}
            ],
            "proteccion_obligatoria": [
                "⚠️ Casco integral/full face certificado",
                "⚠️ Peto/body armor con protección de espalda",
                "⚠️ Coderas y rodilleras de DH",
                "⚠️ Guantes de dedo completo y gafas de protección"
            ],
            "mantenimiento": {
                "cada_bajada": "Inspeccionar cuadro, verificar ruedas, limpiar suspensión",
                "25-30_horas": "Servicio de estáncares horquilla, servicio básico amortiguador",
                "50-75_horas": "Servicio completo suspensión, rebuild amortiguador"
            },
            "garantia": "2 años (uso DH tiene garantía reducida)",
            "precio": "5.999 €",
            "contacto": {
                "web": "www.ultimatedh.com",
                "email": "soporte@ultimatedh.com",
                "telefono": "+34 900 678 901"
            }
        }
    },
    
    "bicicleta_mondracer": {
        "titulo": "Guía para Padres y Niños",
        "subtitulo": "Bicicleta Infantil Mondracer",
        "contenido": {
            "descripcion": "La Mondracer Infant Bike está diseñada específicamente para niños de 2 a 5 años que están aprendiendo a andar en bicicleta. Con características de seguridad premium y diseño ergonómico.",
            "tallas": [
                {"edad": "2-3 años", "altura": "85-100 cm", "bicicleta": "12\"", "entrepierna": "35-42 cm"},
                {"edad": "3-4 años", "altura": "95-110 cm", "bicicleta": "14\"", "entrepierna": "40-48 cm"},
                {"edad": "4-5 años", "altura": "105-120 cm", "bicicleta": "16\"", "entrepierna": "45-55 cm"}
            ],
            "especificaciones": {
                "cuadro": "Acero al carbono con pintura no tóxica, diseño step-through",
                "ruedas": "12\", 14\" o 16\" según modelo",
                "frenos": "V-brake delantero + freno de contrapedal trasero",
                "transmisión": "Velocidad única con guarda-cadena completo",
                "peso": "8.5-10.0 kg (según talla, con ruedas de entrenamiento)",
                "accesorios": "Ruedas de entrenamiento, timbre, reflectores, guardabarros"
            },
            "seguridad": [
                "✅ Guarda-cadena completo",
                "✅ Protectores de manillar acolchados",
                "✅ Reflectores 360° (delantero, trasero, pedales, ruedas)",
                "✅ Límite de giro del manillar",
                "✅ Certificación CE EN 14765"
            ],
            "aprendizaje": {
                "fase1": "Familiarización con ruedas de entrenamiento (Días 1-3)",
                "fase2": "Primeros pedaleos con ruedas (Días 4-10)",
                "fase3": "Elevar gradualmente ruedas de entrenamiento (Días 10-21)",
                "fase4": "Sin ruedas de entrenamiento (Día 21+)"
            },
            "proteccion": "⚠️ SIEMPRE usar casco certificado CE EN1078",
            "garantia": {
                "cuadro": "3 años contra defectos de fabricación",
                "componentes": "1 año"
            },
            "precios": [
                {"modelo": "Mondracer 12\"", "precio": "169 €"},
                {"modelo": "Mondracer 14\"", "precio": "189 €"},
                {"modelo": "Mondracer 16\"", "precio": "209 €"}
            ],
            "contacto": {
                "web": "www.mondracer.com",
                "email": "familias@mondracer.com",
                "telefono": "+34 900 789 012"
            }
        }
    },
    
    "botas_esqui": {
        "titulo": "Guía Técnica y de Uso",
        "subtitulo": "Botas de Esquí TDBootz Special",
        "contenido": {
            "descripcion": "Las TDBootz Special son botas de esquí alpino de alto rendimiento diseñadas para esquiadores avanzados y expertos. Combinan precisión, potencia y comodidad con tecnología de moldeo térmico.",
            "modelos": [
                {"modelo": "TDBootz 110", "flex": "110", "nivel": "Avanzado", "peso": "65-85 kg"},
                {"modelo": "TDBootz 120", "flex": "120", "nivel": "Experto", "peso": "75-95 kg"},
                {"modelo": "TDBootz 130", "flex": "130", "nivel": "Experto/Race", "peso": "85+ kg"}
            ],
            "caracteristicas": {
                "carcasa": "Poliuretano (PU) de alto rendimiento, ancho 100mm",
                "botín": "EVA termoformable doble densidad con Thinsulate 200g",
                "cierre": "4 hebillas de aluminio micro-ajustables + Power Strap 50mm",
                "suela": "ISO 5355 (Alpine/DIN), GripWalk opcional",
                "moldeable": "Termoformable a 80°C (servicio profesional)",
                "peso": "1.950-2.050g por bota (talla 27.0)"
            },
            "tallaje": [
                {"EUR": "40", "US": "7", "Mondo": "25.0-25.5"},
                {"EUR": "41", "US": "8", "Mondo": "26.0-26.5"},
                {"EUR": "42", "US": "9", "Mondo": "27.0-27.5"},
                {"EUR": "43", "US": "10", "Mondo": "28.0-28.5"},
                {"EUR": "44", "US": "11", "Mondo": "29.0-29.5"}
            ],
            "ajuste_correcto": [
                "✓ Dedos tocan punta pero no duelen (de pie)",
                "✓ Al flexionar, dedos se liberan ligeramente",
                "✓ Talón NO se levanta al flexionar",
                "✓ Sin puntos de presión extrema"
            ],
            "mantenimiento": {
                "diario": "Secar botín al aire, usar secadores de botas",
                "semanal": "Limpiar carcasa, desinfectar botín",
                "anual": "Revisión profesional, reemplazo de piezas desgastadas"
            },
            "garantia": "2 años contra defectos de fabricación",
            "precios": [
                {"modelo": "TDBootz 110", "precio": "449 €"},
                {"modelo": "TDBootz 120", "precio": "499 €"},
                {"modelo": "TDBootz 130", "precio": "549 €"}
            ],
            "contacto": {
                "web": "www.tdbootz.com",
                "email": "soporte@tdbootz.com",
                "telefono": "+34 900 890 123"
            }
        }
    }
}

