#!/usr/bin/env python3
"""
Generador completo de PDFs en español para Cortex Search
Usa los datos estructurados en datos_documentos.py
"""

from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle, ListFlowable, ListItem
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_JUSTIFY
import os
from datos_documentos import DOCUMENTOS

# Crear carpeta de salida
OUTPUT_DIR = "documentos_espanol"
os.makedirs(OUTPUT_DIR, exist_ok=True)

def crear_estilos():
    """Crear estilos personalizados"""
    styles = getSampleStyleSheet()
    
    styles.add(ParagraphStyle(
        name='TituloPrincipal',
        parent=styles['Heading1'],
        fontSize=22,
        textColor=colors.HexColor('#1a5490'),
        spaceAfter=15,
        alignment=TA_CENTER,
        fontName='Helvetica-Bold'
    ))
    
    styles.add(ParagraphStyle(
        name='Subtitulo',
        parent=styles['Heading2'],
        fontSize=14,
        textColor=colors.HexColor('#2a75bb'),
        spaceAfter=10,
        spaceBefore=10,
        fontName='Helvetica-Bold'
    ))
    
    styles.add(ParagraphStyle(
        name='Seccion',
        parent=styles['Heading3'],
        fontSize=11,
        textColor=colors.HexColor('#333333'),
        spaceAfter=6,
        spaceBefore=8,
        fontName='Helvetica-Bold'
    ))
    
    styles.add(ParagraphStyle(
        name='TextoNormal',
        parent=styles['Normal'],
        fontSize=9.5,
        alignment=TA_JUSTIFY,
        spaceAfter=5,
        fontName='Helvetica'
    ))
    
    styles.add(ParagraphStyle(
        name='ListaItem',
        parent=styles['Normal'],
        fontSize=9.5,
        leftIndent=15,
        spaceAfter=3,
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
        ('FONTSIZE', (0, 0), (-1, 0), 10),
        ('BOTTOMPADDING', (0, 0), (-1, 0), 10),
        ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
        ('GRID', (0, 0), (-1, -1), 1, colors.grey),
        ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 1), (-1, -1), 8.5),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#f8f8f8')]),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
    ]))
    return table

def generar_pdf_generico(nombre_archivo, doc_data):
    """Generador genérico de PDFs"""
    filename = f"{OUTPUT_DIR}/{nombre_archivo}.pdf"
    doc = SimpleDocTemplate(filename, pagesize=letter,
                           rightMargin=60, leftMargin=60,
                           topMargin=60, bottomMargin=25)
    
    story = []
    styles = crear_estilos()
    contenido = doc_data['contenido']
    
    # Títulos
    story.append(Paragraph(doc_data['titulo'], styles['TituloPrincipal']))
    story.append(Paragraph(doc_data['subtitulo'], styles['TituloPrincipal']))
    story.append(Spacer(1, 15))
    
    # Descripción
    if 'descripcion' in contenido:
        story.append(Paragraph(contenido['descripcion'], styles['TextoNormal']))
        story.append(Spacer(1, 10))
    
    # Modelos (si existen)
    if 'modelos' in contenido:
        story.append(Paragraph("Modelos Disponibles", styles['Subtitulo']))
        
        # Crear tabla de modelos
        headers = list(contenido['modelos'][0].keys())
        headers = [h.replace('_', ' ').title() for h in headers]
        
        tabla_data = [headers]
        for modelo in contenido['modelos']:
            tabla_data.append(list(modelo.values()))
        
        # Ajustar anchos de columna
        num_cols = len(headers)
        col_width = 6.5 * inch / num_cols
        story.append(crear_tabla(tabla_data, col_widths=[col_width] * num_cols))
        story.append(Spacer(1, 10))
    
    # Construcción (si existe)
    if 'construccion' in contenido:
        story.append(Paragraph("Construcción", styles['Seccion']))
        for item in contenido['construccion']:
            story.append(Paragraph(f"• <b>{item.split(':')[0]}:</b> {':'.join(item.split(':')[1:])}" if ':' in item else f"• {item}", 
                                 styles['ListaItem']))
        story.append(Spacer(1, 8))
    
    # Especificaciones (si existe)
    if 'especificaciones' in contenido:
        story.append(Paragraph("Especificaciones Técnicas", styles['Subtitulo']))
        for key, value in contenido['especificaciones'].items():
            key_formatted = key.replace('_', ' ').title()
            story.append(Paragraph(f"• <b>{key_formatted}:</b> {value}", styles['ListaItem']))
        story.append(Spacer(1, 10))
    
    # Rendimiento (si existe)
    if 'rendimiento' in contenido:
        story.append(Paragraph("Rendimiento", styles['Seccion']))
        for key, value in contenido['rendimiento'].items():
            key_formatted = key.replace('_', ' ').title()
            story.append(Paragraph(f"• <b>{key_formatted}:</b> {value}", styles['ListaItem']))
        story.append(Spacer(1, 8))
    
    # Seguridad (si existe)
    if 'seguridad' in contenido:
        story.append(Paragraph("⚠️ Seguridad", styles['Seccion']))
        for item in contenido['seguridad']:
            story.append(Paragraph(item, styles['ListaItem']))
        story.append(Spacer(1, 8))
    
    # Protección obligatoria (si existe)
    if 'proteccion_obligatoria' in contenido:
        story.append(Paragraph("Equipo de Protección Obligatorio", styles['Seccion']))
        for item in contenido['proteccion_obligatoria']:
            story.append(Paragraph(item, styles['ListaItem']))
        story.append(Spacer(1, 8))
    
    # Mantenimiento (si existe)
    if 'mantenimiento' in contenido:
        story.append(Paragraph("Mantenimiento", styles['Subtitulo']))
        mant = contenido['mantenimiento']
        if isinstance(mant, dict):
            for key, value in mant.items():
                key_formatted = key.replace('_', ' ').title()
                story.append(Paragraph(f"• <b>{key_formatted}:</b> {value}", styles['ListaItem']))
        story.append(Spacer(1, 10))
    
    # Garantía
    if 'garantia' in contenido:
        story.append(Paragraph("Garantía", styles['Seccion']))
        garantia = contenido['garantia']
        if isinstance(garantia, str):
            story.append(Paragraph(garantia, styles['TextoNormal']))
        elif isinstance(garantia, dict):
            for key, value in garantia.items():
                key_formatted = key.replace('_', ' ').title()
                story.append(Paragraph(f"• <b>{key_formatted}:</b> {value}", styles['ListaItem']))
        story.append(Spacer(1, 8))
    
    # Precio
    if 'precio' in contenido:
        story.append(Paragraph(f"<b>Precio:</b> {contenido['precio']}", styles['TextoNormal']))
        story.append(Spacer(1, 5))
    
    # Precios (tabla)
    if 'precios' in contenido:
        story.append(Paragraph("Precios", styles['Seccion']))
        tabla_data = [['Modelo', 'Precio']]
        for precio in contenido['precios']:
            tabla_data.append([precio['modelo'], precio['precio']])
        story.append(crear_tabla(tabla_data, col_widths=[4*inch, 2*inch]))
        story.append(Spacer(1, 8))
    
    # Contacto
    if 'contacto' in contenido:
        story.append(Spacer(1, 10))
        story.append(Paragraph("Información de Contacto", styles['Seccion']))
        contacto = contenido['contacto']
        if 'web' in contacto:
            story.append(Paragraph(f"Web: {contacto['web']}", styles['TextoNormal']))
        if 'email' in contacto:
            story.append(Paragraph(f"Email: {contacto['email']}", styles['TextoNormal']))
        if 'telefono' in contacto:
            story.append(Paragraph(f"Teléfono: {contacto['telefono']}", styles['TextoNormal']))
    
    # Generar PDF
    doc.build(story)
    print(f"✓ Creado: {filename}")

# Mapeo de claves a nombres de archivo
ARCHIVOS = {
    'esquis_carver': 'Guia_Especificaciones_Esquis_Carver',
    'esquis_racingfast': 'Guia_Especificaciones_Esquis_RacingFast',
    'esquis_outpiste': 'Guia_Especificaciones_Esquis_OutPiste',
    'bicicleta_premium': 'Guia_Usuario_Bicicleta_Premium',
    'bicicleta_xtreme': 'Bicicleta_Xtreme_Road_105_SL',
    'bicicleta_downhill': 'Bicicleta_Ultimate_Downhill',
    'bicicleta_mondracer': 'Bicicleta_Infantil_Mondracer',
    'botas_esqui': 'Botas_Esqui_TDBootz_Special'
}

if __name__ == "__main__":
    print("="*60)
    print("Generando todos los PDFs en español con formato profesional")
    print("="*60)
    print("")
    
    for key, nombre_archivo in ARCHIVOS.items():
        if key in DOCUMENTOS:
            generar_pdf_generico(nombre_archivo, DOCUMENTOS[key])
    
    print("")
    print("="*60)
    print(f"✓ {len(ARCHIVOS)} PDFs creados exitosamente")
    print(f"✓ Ubicación: {OUTPUT_DIR}/")
    print("="*60)
    print("")
    print("Los PDFs están en español con formato profesional:")
    print("- Colores corporativos azules")
    print("- Tablas con formato atractivo")
    print("- Estructura clara y legible")
    print("- Fuentes Helvetica (estándar PDF)")

