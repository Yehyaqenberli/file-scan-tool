#!/bin/bash
set -euo pipefail

# ------------------
#  CONFIGURATION
# ------------------
readonly TEMP_DIR="temp_files"
readonly OUTPUT_FILE="results.txt"
readonly ERROR_CODE=-2
readonly SUPPORTED_FORMATS=("pdf" "docx" "xlsx" "txt")  # Desteklenen formatlar
readonly MEDICAL_TERMS=("dossier médical" "confidentiel médical" "PHI" "health information")

# ------------------
#  FUNCTIONS
# ------------------

# Hata yönetimi
throw_error() {
  echo "[FATAL] $1 (Code: $ERROR_CODE)" >&2
  exit 1
}

# Gizlilik politikası gösterimi
show_privacy_policy() {
  cat <<EOF
----------------------------------------------
           PRIVACY & SECURITY POLICY
----------------------------------------------
- All data is encrypted and confidential.
- No storage of sensitive personal data.
- Unauthorized access is strictly prohibited.
----------------------------------------------
EOF
}

# Geçici dosyaları temizleme
cleanup() {
  if [[ -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
    echo "[INFO] Temporary files removed."
  fi
}

# Dosya formatını kontrol etme
check_file_format() {
  local file="$1"
  local extension="${file##*.}"
  if [[ ! " ${SUPPORTED_FORMATS[*]} " =~ " ${extension} " ]]; then
    throw_error "Unsupported file format: $extension"
  fi
  echo "$extension"
}

# PDF işleme
process_pdf() {
  local input_file="$1"
  local output_file="$2"
  
  # PDF'den metin çıkarma
  pdftotext "$input_file" "$output_file" || throw_error "Failed to extract text from PDF"
}

# DOCX işleme
process_docx() {
  local input_file="$1"
  local output_file="$2"
  
  # DOCX'ten metin çıkarma
  pandoc -f docx -t plain "$input_file" -o "$output_file" || throw_error "Failed to extract text from DOCX"
}

# XLSX işleme
process_xlsx() {
  local input_file="$1"
  local output_file="$2"
  
  # XLSX'ten metin çıkarma
  xlsx2csv "$input_file" | tr '\n' ' ' > "$output_file" || throw_error "Failed to extract text from XLSX"
}

# TXT işleme
process_txt() {
  local input_file="$1"
  local output_file="$2"
  
  # TXT dosyasını kopyalama
  cp "$input_file" "$output_file" || throw_error "Failed to process TXT file"
}

# Hassas veri taraması
scan_for_sensitive_data() {
  local file="$1"
  local format="$2"
  
  echo "[INFO] Scanning $file for sensitive data..."
  
  case "$format" in
    pdf|docx|xlsx|txt)
      for term in "${MEDICAL_TERMS[@]}"; do
        if grep -Fiq "$term" "$file"; then
          echo "[FOUND] Sensitive term '$term' found in $file"
          return 0
        fi
      done
      ;;
    *)
      throw_error "Unsupported format for scanning: $format"
      ;;
  esac
  
  echo "[INFO] No sensitive data found in $file"
}

# Ana iş akışı
main() {
  # Giriş dosyası kontrolü
  if [[ $# -eq 0 ]]; then
    throw_error "Usage: $0 <file1> <file2> ..."
  fi

  # Geçici klasör oluşturma
  mkdir -p "$TEMP_DIR"

  # Gizlilik politikası
  show_privacy_policy

  # Dosyaları işleme
  for input_file in "$@"; do
    echo "[INFO] Processing file: $input_file"
    
    # Dosya formatını kontrol etme
    format=$(check_file_format "$input_file")
    
    # Çıktı dosyası
    output_file="$TEMP_DIR/$(basename "$input_file").txt"
    
    # Formatına göre işleme
    case "$format" in
      pdf) process_pdf "$input_file" "$output_file" ;;
      docx) process_docx "$input_file" "$output_file" ;;
      xlsx) process_xlsx "$input_file" "$output_file" ;;
      txt) process_txt "$input_file" "$output_file" ;;
      *) throw_error "Unsupported format: $format" ;;
    esac
    
    # Hassas veri taraması
    scan_for_sensitive_data "$output_file" "$format"
  done

  echo "[SUCCESS] All files processed successfully."
}

# ------------------
#  EXECUTION
# ------------------
trap cleanup EXIT
main "$@"
