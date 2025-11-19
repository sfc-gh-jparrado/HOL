#!/usr/bin/env python3
"""
Script para crear PDFs en español con formato profesional
usando ReportLab para el quickstart de Cortex Search
"""

from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_JUSTIFY
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
import os

# Crear carpeta para PDFs en español
output_dir = "documentos_espanol"
os.makedirs(output_dir, exist_ok=True)

def crear_estilos():
    """Crear estilos personalizados para los documentos"""
    styles = getSampleStyleSheet()
    
    # Título principal
    styles.add(ParagraphStyle(
        name='TituloPrincipal',
        parent=styles['Heading1'],
        fontSize=24,
        textColor=colors.HexColor('#1a5490'),
        spaceAfter=20,
        alignment=TA_CENTER,
        fontName='Helvetica-Bold'
    ))
    
    # Subtítulo
    styles.add(ParagraphStyle(
        name='Subtitulo',
        parent=styles['Heading2'],
        fontSize=16,
        textColor=colors.HexColor('#2a75bb'),
        spaceAfter=12,
        spaceBefore=12,
        fontName='Helvetica-Bold'
    ))
    
    # Sección
    styles.add(ParagraphStyle(
        name='Seccion',
        parent=styles['Heading3'],
        fontSize=12,
        textColor=colors.HexColor('#333333'),
        spaceAfter=8,
        spaceBefore=10,
        fontName='Helvetica-Bold'
    ))
    
    # Texto normal
    styles.add(ParagraphStyle(
        name='TextoNormal',
        parent=styles['Normal'],
        fontSize=10,
        alignment=TA_JUSTIFY,
        spaceAfter=6,
        fontName='Helvetica'
    ))
    
    # Lista
    styles.add(ParagraphStyle(
        name='ListaItem',
        parent=styles['Normal'],
        fontSize=10,
        leftIndent=20,
        spaceAfter=4,
        fontName='Helvetica'
    ))
    
    return styles

def crear_tabla(data, col_widths=None):
    """Crear tabla con estilo profesional"""
    table = Table(data, colWidths=col_widths)
    table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1a5490')),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, 0), 11),
        ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
        ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
        ('GRID', (0, 0), (-1, -1), 1, colors.grey),
        ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 1), (-1, -1), 9),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#f0f0f0')]),
    ]))
    return table

def crear_pdf_esquis_carver():
    """Crear PDF para Esquís Carver Pro Series"""
    filename = f"{output_dir}/Guia_Especificaciones_Esquis_Carver.pdf"
    doc = SimpleDocTemplate(filename, pagesize=letter,
                           rightMargin=72, leftMargin=72,
                           topMargin=72, bottomMargin=18)
    
    story = []
    styles = crear_estilos()
    
    # Título
    story.append(Paragraph("Guía de Especificaciones", styles['TituloPrincipal']))
    story.append(Paragraph("Esquís Carver Pro Series", styles['TituloPrincipal']))
    story.append(Spacer(1, 20))
    
    # Descripción general
    story.append(Paragraph("Descripción General", styles['Subtitulo']))
    story.append(Paragraph(
        "Los Esquís Carver Pro Series están diseñados para esquiadores avanzados que buscan "
        "precisión y control en pistas preparadas. Fabricados con tecnología de punta y materiales "
        "de alta calidad, ofrecen un rendimiento excepcional en todo tipo de nieve compactada.",
        styles['TextoNormal']
    ))
    story.append(Spacer(1, 12))
    
    # Modelos disponibles
    story.append(Paragraph("Modelos Disponibles", styles['Seccion']))
    modelos_data = [
        ['Modelo', 'Longitud', 'Nivel', 'Peso Esquiador'],
        ['Carver Pro 170', '170 cm', 'Intermedio-Avanzado', '60-75 kg'],
        ['Carver Pro 180', '180 cm', 'Avanzado-Experto', '70-85 kg'],
        ['Carver Pro 190', '190 cm', 'Experto', '80-95 kg'],
    ]
    story.append(crear_tabla(modelos_data, col_widths=[2*inch, 1.5*inch, 1.8*inch, 1.5*inch]))
    story.append(Spacer(1, 12))
    
    # Especificaciones técnicas
    story.append(Paragraph("Especificaciones Técnicas", styles['Subtitulo']))
    
    story.append(Paragraph("Construcción", styles['Seccion']))
    story.append(Paragraph("• <b>Núcleo:</b> Madera de álamo y haya laminada con fibra de carbono", styles['ListaItem']))
    story.append(Paragraph("• <b>Base:</b> Base sinterizada P-Tex 4000 para máxima velocidad", styles['ListaItem']))
    story.append(Paragraph("• <b>Cantos:</b> Acero templado de 2.5mm para mayor durabilidad", styles['ListaItem']))
    story.append(Paragraph("• <b>Laminado superior:</b> Fibra de vidrio triaxial", styles['ListaItem']))
    story.append(Spacer(1, 10))
    
    story.append(Paragraph("Geometría", styles['Seccion']))
    geometria_data = [
        ['Medida', 'Carver 170', 'Carver 180', 'Carver 190'],
        ['Radio de giro', '14.5 m', '16.2 m', '18.0 m'],
        ['Ancho espátula', '128 mm', '128 mm', '128 mm'],
        ['Ancho patín', '75 mm', '75 mm', '75 mm'],
        ['Ancho cola', '115 mm', '115 mm', '115 mm'],
        ['Camber', '2.8 mm', '2.8 mm', '2.8 mm'],
    ]
    story.append(crear_tabla(geometria_data, col_widths=[1.8*inch, 1.5*inch, 1.5*inch, 1.5*inch]))
    story.append(Spacer(1, 12))
    
    # Nueva página
    story.append(PageBreak())
    
    # Rendimiento
    story.append(Paragraph("Rendimiento", styles['Subtitulo']))
    story.append(Paragraph("Tipo de Nieve", styles['Seccion']))
    story.append(Paragraph("• <b>Óptimo:</b> Nieve compactada y pistas preparadas", styles['ListaItem']))
    story.append(Paragraph("• <b>Bueno:</b> Nieve dura y hielo", styles['ListaItem']))
    story.append(Paragraph("• <b>Limitado:</b> Nieve profunda y fuera de pista", styles['ListaItem']))
    story.append(Spacer(1, 10))
    
    story.append(Paragraph("Estilo de Esquí", styles['Seccion']))
    story.append(Paragraph("• Carving agresivo en pistas preparadas", styles['ListaItem']))
    story.append(Paragraph("• Giros cortos a medianos de alta precisión", styles['ListaItem']))
    story.append(Paragraph("• Alta velocidad en descensos", styles['ListaItem']))
    story.append(Paragraph("• Excelente estabilidad a velocidades elevadas", styles['ListaItem']))
    story.append(Spacer(1, 12))
    
    # Mantenimiento
    story.append(Paragraph("Mantenimiento Recomendado", styles['Subtitulo']))
    
    story.append(Paragraph("Afilado de Cantos", styles['Seccion']))
    story.append(Paragraph("• <b>Frecuencia:</b> Cada 5-7 días de uso", styles['ListaItem']))
    story.append(Paragraph("• <b>Ángulo:</b> 88° base, 1° lateral", styles['ListaItem']))
    story.append(Spacer(1, 8))
    
    story.append(Paragraph("Encerado", styles['Seccion']))
    story.append(Paragraph("• <b>Frecuencia:</b> Cada 3-4 días de uso", styles['ListaItem']))
    story.append(Paragraph("• <b>Tipo de cera:</b> Universal o específica según temperatura", styles['ListaItem']))
    story.append(Paragraph("• <b>Temperatura aplicación:</b> 140-150°C", styles['ListaItem']))
    story.append(Spacer(1, 12))
    
    # Garantía y precio
    story.append(Paragraph("Garantía y Precio", styles['Subtitulo']))
    story.append(Paragraph(
        "<b>Garantía:</b> 2 años contra defectos de fabricación (cubre núcleo, cantos y laminado). "
        "No cubre desgaste normal o daños por uso incorrecto.",
        styles['TextoNormal']
    ))
    story.append(Spacer(1, 8))
    
    precios_data = [
        ['Modelo', 'Precio'],
        ['Carver Pro 170', '749 €'],
        ['Carver Pro 180', '799 €'],
        ['Carver Pro 190', '849 €'],
    ]
    story.append(crear_tabla(precios_data, col_widths=[4*inch, 2*inch]))
    story.append(Spacer(1, 10))
    story.append(Paragraph("<i>* Precios sujetos a variación según distribuidor y temporada</i>", 
                          styles['TextoNormal']))
    
    # Información de contacto
    story.append(Spacer(1, 15))
    story.append(Paragraph("Información de Contacto", styles['Seccion']))
    story.append(Paragraph("Email: soporte@carver-skis.com", styles['TextoNormal']))
    story.append(Paragraph("Teléfono: +34 900 123 456", styles['TextoNormal']))
    story.append(Paragraph("Web: www.carver-skis.com", styles['TextoNormal']))
    
    # Generar PDF
    doc.build(story)
    print(f"✓ Creado: {filename}")

def crear_pdf_bicicleta_premium():
    """Crear PDF para Bicicleta Premium"""
    filename = f"{output_dir}/Guia_Usuario_Bicicleta_Premium.pdf"
    doc = SimpleDocTemplate(filename, pagesize=letter,
                           rightMargin=72, leftMargin=72,
                           topMargin=72, bottomMargin=18)
    
    story = []
    styles = crear_estilos()
    
    # Título
    story.append(Paragraph("Guía de Usuario", styles['TituloPrincipal']))
    story.append(Paragraph("Bicicleta Premium Road Master 3000", styles['TituloPrincipal']))
    story.append(Spacer(1, 20))
    
    story.append(Paragraph("¡Felicidades por tu Nueva Bicicleta!", styles['Subtitulo']))
    story.append(Paragraph(
        "Gracias por elegir la Bicicleta Premium Road Master 3000. Este manual te ayudará a conocer, "
        "mantener y disfrutar al máximo de tu nueva bicicleta de carretera de alto rendimiento.",
        styles['TextoNormal']
    ))
    story.append(Spacer(1, 15))
    
    # Especificaciones
    story.append(Paragraph("Especificaciones Técnicas", styles['Subtitulo']))
    
    story.append(Paragraph("Cuadro y Horquilla", styles['Seccion']))
    story.append(Paragraph("• <b>Cuadro:</b> Aluminio 6061-T6 hydroformed, geometría racing", styles['ListaItem']))
    story.append(Paragraph("• <b>Tallas:</b> XS (48cm), S (52cm), M (56cm), L (58cm), XL (61cm)", styles['ListaItem']))
    story.append(Paragraph("• <b>Horquilla:</b> Carbono full monocoque", styles['ListaItem']))
    story.append(Paragraph("• <b>Peso cuadro:</b> 1.250g (talla M)", styles['ListaItem']))
    story.append(Spacer(1, 10))
    
    story.append(Paragraph("Grupo de Transmisión Shimano 105", styles['Seccion']))
    story.append(Paragraph("• <b>Grupo:</b> Shimano 105 R7000 (11 velocidades)", styles['ListaItem']))
    story.append(Paragraph("• <b>Cassette:</b> 11-30T", styles['ListaItem']))
    story.append(Paragraph("• <b>Platos:</b> 50/34T (compacto)", styles['ListaItem']))
    story.append(Paragraph("• <b>Frenos:</b> Shimano 105 R7000 dual pivot", styles['ListaItem']))
    story.append(Spacer(1, 10))
    
    story.append(Paragraph("Ruedas y Neumáticos", styles['Seccion']))
    story.append(Paragraph("• <b>Ruedas:</b> Llantas de aleación de doble pared, 28\"", styles['ListaItem']))
    story.append(Paragraph("• <b>Neumáticos:</b> Continental Ultra Sport 700x25C", styles['ListaItem']))
    story.append(Paragraph("• <b>Presión recomendada:</b> 90-120 PSI (6.2-8.3 bar)", styles['ListaItem']))
    story.append(Spacer(1, 12))
    
    # Nueva página
    story.append(PageBreak())
    
    # Montaje inicial
    story.append(Paragraph("Montaje Inicial", styles['Subtitulo']))
    
    story.append(Paragraph("Herramientas Necesarias", styles['Seccion']))
    story.append(Paragraph("• Llaves Allen: 4mm, 5mm, 6mm", styles['ListaItem']))
    story.append(Paragraph("• Llave de 15mm (para pedales)", styles['ListaItem']))
    story.append(Paragraph("• Bomba de piso con manómetro", styles['ListaItem']))
    story.append(Spacer(1, 10))
    
    story.append(Paragraph("Ajuste del Sillín", styles['Seccion']))
    story.append(Paragraph(
        "<b>Altura correcta:</b> Con la pierna extendida, debe quedar ligeramente flexionada en el punto más bajo. "
        "Fórmula aproximada: Entrepierna x 0.883",
        styles['TextoNormal']
    ))
    story.append(Spacer(1, 8))
    
    presion_data = [
        ['Peso del Ciclista', 'Presión Recomendada'],
        ['< 60 kg', '90-95 PSI'],
        ['60-75 kg', '95-105 PSI'],
        ['75-90 kg', '105-115 PSI'],
        ['> 90 kg', '115-120 PSI'],
    ]
    story.append(crear_tabla(presion_data, col_widths=[3*inch, 3*inch]))
    story.append(Spacer(1, 12))
    
    # Mantenimiento
    story.append(Paragraph("Mantenimiento Regular", styles['Subtitulo']))
    
    story.append(Paragraph("Después de Cada Salida", styles['Seccion']))
    story.append(Paragraph("• Limpiar cuadro con paño húmedo", styles['ListaItem']))
    story.append(Paragraph("• Remover barro de ruedas", styles['ListaItem']))
    story.append(Paragraph("• Secar cadena si estuvo bajo lluvia", styles['ListaItem']))
    story.append(Spacer(1, 10))
    
    story.append(Paragraph("Mantenimiento Semanal", styles['Seccion']))
    story.append(Paragraph("• Limpiar y lubricar cadena", styles['ListaItem']))
    story.append(Paragraph("• Verificar y ajustar presión de neumáticos", styles['ListaItem']))
    story.append(Paragraph("• Inspeccionar desgaste de pastillas de freno", styles['ListaItem']))
    story.append(Spacer(1, 10))
    
    story.append(Paragraph("Mantenimiento Mensual", styles['Seccion']))
    story.append(Paragraph("• Limpieza profunda completa", styles['ListaItem']))
    story.append(Paragraph("• Verificar elongación de cadena", styles['ListaItem']))
    story.append(Paragraph("• Centrado de ruedas si es necesario", styles['ListaItem']))
    story.append(Paragraph("• Ajuste completo de cambios y frenos", styles['ListaItem']))
    story.append(Spacer(1, 15))
    
    # Garantía
    story.append(Paragraph("Garantía", styles['Subtitulo']))
    story.append(Paragraph(
        "<b>Cuadro y horquilla:</b> 5 años contra defectos de fabricación<br/>"
        "<b>Componentes:</b> 2 años contra defectos de fabricación<br/>"
        "<b>Ruedas y neumáticos:</b> 1 año",
        styles['TextoNormal']
    ))
    story.append(Spacer(1, 15))
    
    # Contacto y precio
    story.append(Paragraph("Información de Contacto", styles['Seccion']))
    story.append(Paragraph("Web: www.roadmaster.com", styles['TextoNormal']))
    story.append(Paragraph("Email: soporte@roadmaster.com", styles['TextoNormal']))
    story.append(Paragraph("Teléfono: +34 900 456 789", styles['TextoNormal']))
    story.append(Spacer(1, 10))
    
    story.append(Paragraph("<b>Peso Total:</b> 9.2 kg (talla M, sin pedales)", styles['TextoNormal']))
    story.append(Paragraph("<b>Precio:</b> Desde 1.299 € (según configuración)", styles['TextoNormal']))
    
    # Generar PDF
    doc.build(story)
    print(f"✓ Creado: {filename}")

# Ejecutar creación de PDFs
if __name__ == "__main__":
    print("Creando PDFs en español con formato profesional...")
    print("")
    
    crear_pdf_esquis_carver()
    crear_pdf_bicicleta_premium()
    
    print("")
    print(f"✓ PDFs creados exitosamente en la carpeta '{output_dir}/'")
    print("")
    print("Nota: Se han creado 2 PDFs de ejemplo. Para crear los 8 PDFs completos,")
    print("agrega las funciones correspondientes para cada documento.")

