// Supabase 연결 설정 (이 파일은 .gitignore로 Git에서 제외됩니다)
//
// ✅ 여기에 넣어도 되는 키: Publishable 키 (sb_publishable_...)
//    브라우저에 노출되도록 만들어진 키이며, 데이터 보호는 테이블의 RLS 정책이 담당합니다.
// ⛔ 절대 넣으면 안 되는 키: Secret 키 (sb_secret_...) / service_role 키
//    이 파일은 브라우저로 전송되므로, 비밀 키를 넣으면 누구나 볼 수 있게 됩니다.

window.APP_CONFIG = {
  SUPABASE_URL: 'https://inkceewuirlktwecsppw.supabase.co',
  SUPABASE_KEY: 'sb_publishable_PS3x35yv_5ZqxH4RH4NdKg__uyWPBtZ',
};
