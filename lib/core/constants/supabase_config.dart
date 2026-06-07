class SupabaseConfig {
  SupabaseConfig._();

  // Remplacer par les vraies valeurs depuis le dashboard Supabase
  // Settings > API > Project URL et anon public key
  static const String supabaseUrl = 'https://dksowmyytsiubnnbmyfo.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRrc293bXl5dHNpdWJubmJteWZvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA4MjI3MzgsImV4cCI6MjA5NjM5ODczOH0.n-zxqXTcb3DhSagNsx2Ol3hxDCtD1GBMhYlCM3uxnLs';

  // Buckets Storage
  static const String bucketLogos        = 'logos';
  static const String bucketSignatures   = 'signatures';
  static const String bucketJustificatifs = 'justificatifs';
  static const String bucketPDFs         = 'pdfs';
}
