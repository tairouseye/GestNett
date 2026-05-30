class SupabaseConfig {
  SupabaseConfig._();

  // Remplacer par les vraies valeurs depuis le dashboard Supabase
  // Settings > API > Project URL et anon public key
  static const String supabaseUrl = 'https://kbwhkqmfbngwgodppdln.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtid2hrcW1mYm5nd2dvZHBwZGxuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAxMzA4MDEsImV4cCI6MjA5NTcwNjgwMX0.xg6s3EqPdfvuEc7JpDW4YVUapqj6dmE7_oNIK6TAs_0';

  // Buckets Storage
  static const String bucketLogos        = 'logos';
  static const String bucketSignatures   = 'signatures';
  static const String bucketJustificatifs = 'justificatifs';
  static const String bucketPDFs         = 'pdfs';
}
