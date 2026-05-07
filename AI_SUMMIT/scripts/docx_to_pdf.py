"""Convierte los DOCX de contratos a PDF usando reportlab.
Mantiene el mismo nombre base, solo cambia la extensión.
Genera PDFs con formato profesional que mantienen estructura de páginas.
"""

from docx import Document
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
from reportlab.lib.colors import HexColor
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
import os
import re

# Registrar fuente DejaVu (soporta UTF-8 / acentos / ñ)
font_paths = [
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/Library/Fonts/Arial Unicode.ttf',
    '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
    '/System/Library/Fonts/Helvetica.ttc',
]
font_registered = False
for fp in font_paths:
    if os.path.exists(fp):
        try:
            pdfmetrics.registerFont(TTFont('CustomSans', fp))
            font_registered = True
            print(f"Fuente cargada: {fp}")
            break
        except Exception as e:
            continue

font_name = 'CustomSans' if font_registered else 'Helvetica'


def docx_to_pdf(docx_path, pdf_path):
    doc = Document(docx_path)
    
    # Estilos
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        'TitleStyle',
        parent=styles['Title'],
        fontName=font_name,
        fontSize=16,
        alignment=TA_CENTER,
        spaceAfter=12,
        textColor=HexColor('#1a3d6d'),
    )
    h1_style = ParagraphStyle(
        'H1Style',
        parent=styles['Heading1'],
        fontName=font_name,
        fontSize=12,
        alignment=TA_LEFT,
        spaceBefore=10,
        spaceAfter=6,
        textColor=HexColor('#1a3d6d'),
    )
    body_style = ParagraphStyle(
        'BodyStyle',
        parent=styles['Normal'],
        fontName=font_name,
        fontSize=10,
        alignment=TA_JUSTIFY,
        leading=14,
        spaceAfter=6,
    )
    bullet_style = ParagraphStyle(
        'BulletStyle',
        parent=body_style,
        leftIndent=18,
        bulletIndent=6,
    )
    italic_style = ParagraphStyle(
        'ItalicStyle',
        parent=body_style,
        alignment=TA_CENTER,
        fontSize=10,
    )
    
    # Crear PDF
    pdf = SimpleDocTemplate(
        pdf_path,
        pagesize=letter,
        leftMargin=2.5*cm,
        rightMargin=2.5*cm,
        topMargin=2.5*cm,
        bottomMargin=2.5*cm,
    )
    
    elements = []
    
    def escape_xml(text):
        """Escapa caracteres XML para reportlab Paragraph."""
        return text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
    
    def runs_to_html(runs):
        """Convierte runs de docx a HTML markup para reportlab."""
        result = ''
        for run in runs:
            text = escape_xml(run.text)
            text = text.replace('\n', '<br/>')
            if run.bold and run.italic:
                result += f'<b><i>{text}</i></b>'
            elif run.bold:
                result += f'<b>{text}</b>'
            elif run.italic:
                result += f'<i>{text}</i>'
            else:
                result += text
        return result
    
    for para in doc.paragraphs:
        # Detectar PageBreak
        page_break_in_para = False
        for run in para.runs:
            if 'lastRenderedPageBreak' in run._element.xml or '<w:br w:type="page"/>' in run._element.xml:
                page_break_in_para = True
                break
        
        text_html = runs_to_html(para.runs)
        if not text_html.strip():
            elements.append(Spacer(1, 6))
            if page_break_in_para:
                elements.append(PageBreak())
            continue
        
        style_name = para.style.name if para.style else 'Normal'
        
        if 'Title' in style_name or style_name == 'Heading 0':
            elements.append(Paragraph(text_html, title_style))
        elif 'Heading 1' in style_name or 'Heading1' in style_name:
            elements.append(Paragraph(text_html, h1_style))
        elif 'List Bullet' in style_name:
            elements.append(Paragraph(f'• {text_html}', bullet_style))
        elif 'List Number' in style_name:
            elements.append(Paragraph(text_html, bullet_style))
        else:
            # Verificar si es un subtítulo italic centrado (segundo párrafo del doc)
            if all(run.italic for run in para.runs if run.text.strip()):
                elements.append(Paragraph(text_html, italic_style))
            else:
                elements.append(Paragraph(text_html, body_style))
        
        if page_break_in_para:
            elements.append(PageBreak())
    
    # Page breaks explícitos vía elementos especiales en docx
    # Re-procesar para detectar w:br type="page"
    pdf.build(elements)
    print(f"✅ PDF generado: {pdf_path}")


# Procesar ambos contratos
docs_dir = '/Users/jparrado/HOL-repo/HOL/AI_SUMMIT/datasets/documentos'
for nombre in ['CONTRATO_ARRENDAMIENTO_01', 'CONTRATO_ARRENDAMIENTO_02']:
    docx_to_pdf(f'{docs_dir}/{nombre}.docx', f'{docs_dir}/{nombre}.pdf')
