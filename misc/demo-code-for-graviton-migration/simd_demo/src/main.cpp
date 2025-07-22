#include "simd_demo.h"

int main() {
    std::cout << "=== SIMD指令集演示程序 ===" << std::endl;
    std::cout << "演示SSE/AVX/AVX2/AVX512指令在不同场景中的应用" << std::endl;
    std::cout << std::endl;
    
    // 检查CPU支持
    print_cpu_features();
    std::cout << std::endl;
    
    // 场景1: 向量数学运算
    std::cout << "=== 场景1: 向量数学运算 ===" << std::endl;
    VectorMath::demo_vector_operations();
    std::cout << std::endl;
    
    // 场景2: 图像处理
    std::cout << "=== 场景2: 图像处理 ===" << std::endl;
    ImageProcessing::demo_image_operations();
    std::cout << std::endl;
    
    // 场景3: 矩阵运算
    std::cout << "=== 场景3: 矩阵运算 ===" << std::endl;
    MatrixOperations::demo_matrix_operations();
    std::cout << std::endl;
    
    // 场景4: 音频处理
    std::cout << "=== 场景4: 音频处理 ===" << std::endl;
    AudioProcessing::demo_audio_operations();
    std::cout << std::endl;
    
    // 场景5: 数据分析
    std::cout << "=== 场景5: 数据分析 ===" << std::endl;
    DataAnalytics::demo_data_operations();
    std::cout << std::endl;
    
    std::cout << "=== 演示完成 ===" << std::endl;
    return 0;
}
