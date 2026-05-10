export default function handler(req, res) {
    const uuid = "35cd7490-4c71-4884-b848-22d6b43ab826"; // الـ UUID بتاعك
    const host = req.headers.host;
    
    // إعداد الـ VLESS الخاص بـ Vercel
    const vlessConfig = `vless://${uuid}@${host}:443?encryption=none&security=tls&sni=${host}&type=ws&host=${host}&path=%2F%3Fed%3D2048#Vercel-Flow-Studio`;

    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    res.status(200).send(`
#######################################
رابط الاتصال الخاص بك:
${vlessConfig}
#######################################
    `);
}
