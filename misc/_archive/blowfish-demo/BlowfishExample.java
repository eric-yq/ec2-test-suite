package test;

import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.util.Base64;

public class BlowfishExample {

    public static void main(String[] args) throws Exception {
        long startTime = System.currentTimeMillis();
        int cnt = 100000;
        for (int i = 0; i < cnt; i++) {
            System.out.println("进度:" + i / (cnt / 100) + "%");
            process(args[0]);
        }
        long endTime = System.currentTimeMillis();
        long timeDifferenceInMillis = endTime - startTime;
        double timeDifferenceInSeconds = timeDifferenceInMillis / 1000.0;
        System.out.println("总耗时：" + timeDifferenceInSeconds + "秒");

    }

    private static void process(String algorithm) throws Exception {
        // 定义秘钥
        String keyString = "ThisIsABlowfishKey";
        byte[] keyBytes = keyString.getBytes(StandardCharsets.UTF_8);
        SecretKey key = new SecretKeySpec(keyBytes, algorithm);

        // 定义要加密的数据
        StringBuilder originalString = new StringBuilder("Hello, world!");
        for (int i = 0; i < 100; i++) {
            originalString.append("Hello, world!");
        }
        byte[] data = originalString.toString().getBytes(StandardCharsets.UTF_8);

        // 加密
        Cipher cipher = Cipher.getInstance(algorithm);
        cipher.init(Cipher.ENCRYPT_MODE, key);
        byte[] encryptedData = cipher.doFinal(data);

        // 将加密后的数据转换成 Base64 字符串以便存储或传输
        String encryptedString = Base64.getEncoder().encodeToString(encryptedData);
        // System.out.println("Encrypted: " + encryptedString);

        // 解密
        cipher.init(Cipher.DECRYPT_MODE, key);
        byte[] decryptedData = cipher.doFinal(Base64.getDecoder().decode(encryptedString));

        // 将解密后的数据转换成字符串
        String decryptedString = new String(decryptedData, StandardCharsets.UTF_8);
        // System.out.println("Decrypted: " + decryptedString);
    }
}