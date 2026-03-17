#include "common.h"
#include "llama.h"

#include <cmath>
#include <cstdio>
#include <string>
#include <cstring>
#include <vector>
#include <mutex>

llama_context * ctx;
llama_model * model;
std::mutex mtx;

// adapted from https://github.com/ggerganov/llama.cpp/blob/b3145/examples/simple/simple.cpp

struct chatbot_response {
    char* output;
    float inference_time;
    int num_tokens; 
};

extern "C" int init() {
    fprintf(stdout, "%s\n", llama_print_system_info());

    llama_backend_init();

    llama_model_params model_params = llama_model_default_params();

    model = llama_load_model_from_url(
        "https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.1-GGUF/resolve/main/mistral-7b-instruct-v0.1.Q4_K_M.gguf?download=true", 
        "/tmp/mistral-7b-instruct-v0.1.Q4_K_M.gguf", 
        model_params);

    if (model == NULL) {
        fprintf(stderr , "%s: error: unable to load model\n" , __func__);
        return 1;
    }

    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = 512;
    ctx_params.n_batch = 512;
    ctx_params.n_ubatch = 512;
    ctx_params.n_threads = 8;
    ctx_params.n_threads_batch = 8;
    ctx_params.seed = 1000;

    ctx = llama_new_context_with_model(model, ctx_params);

    if (ctx == NULL) {
        fprintf(stderr , "%s: error: failed to create the llama_context\n" , __func__);
        return 1;
    }

    return 0;
}

extern "C" int predict(const char* prompt, int n_predict, chatbot_response* response)
{
    std::lock_guard<std::mutex> lock(mtx);

    LOG_TEE("\nRequest: %s\n", prompt);
    fflush(stdout);

    llama_reset_timings(ctx);
    llama_kv_cache_clear(ctx);

    std::vector<llama_token> tokens_list;
    tokens_list = llama_tokenize(ctx, std::string(prompt), true);

    const int n_ctx    = llama_n_ctx(ctx);
    const int n_kv_req = tokens_list.size() + (n_predict - tokens_list.size());

    if (n_kv_req > n_ctx) {
        fprintf(stderr, "%s: error: n_kv_req > n_ctx, the required KV cache size is not big enough\n", __func__);
        fprintf(stderr, "%s:        either reduce n_predict or increase n_ctx\n", __func__);
        return 1;
    }

    llama_batch batch = llama_batch_init(512, 0, 1);

    for (size_t i = 0; i < tokens_list.size(); i++) {
        llama_batch_add(batch, tokens_list[i], i, { 0 }, false);
    }

    batch.logits[batch.n_tokens - 1] = true;

    if (llama_decode(ctx, batch) != 0) {
        fprintf(stderr, "%s: llama_decode() failed\n", __func__);
        return 1;
    }

    int n_cur    = batch.n_tokens;
    int n_decode = 0;

    std::string prompt_response;

    LOG_TEE("Response: ");

    while (n_cur <= n_predict) {
        {
            auto   n_vocab = llama_n_vocab(model);
            auto * logits  = llama_get_logits_ith(ctx, batch.n_tokens - 1);

            std::vector<llama_token_data> candidates;
            candidates.reserve(n_vocab);

            for (llama_token token_id = 0; token_id < n_vocab; token_id++) {
                candidates.emplace_back(llama_token_data{ token_id, logits[token_id], 0.0f });
            }

            llama_token_data_array candidates_p = { candidates.data(), candidates.size(), false };

            const llama_token new_token_id = llama_sample_token_greedy(ctx, &candidates_p);

            if (llama_token_is_eog(model, new_token_id) || n_cur == n_predict) {
                break;
            }

            LOG_TEE("%s", llama_token_to_piece(ctx, new_token_id).c_str());
            fflush(stdout);

            prompt_response += llama_token_to_piece(ctx, new_token_id);

            llama_batch_clear(batch);
            llama_batch_add(batch, new_token_id, n_cur, { 0 }, true);

            n_decode += 1;
        }

        n_cur += 1;

        if (llama_decode(ctx, batch)) {
            fprintf(stderr, "%s : failed to eval, return code %d\n", __func__, 1);
            return 1;
        }
    }
    LOG_TEE("\n");
    fflush(stdout);

    llama_batch_free(batch);

    char* msg = new char[prompt_response.size() + 1];
    msg[prompt_response.size()] = '\0';

    std::copy(prompt_response.begin(), prompt_response.end(), msg);

    llama_timings timings = llama_get_timings(ctx);
    float inference_time = timings.t_end_ms - timings.t_start_ms;
    int tokens = tokens_list.size() + n_decode;
    *response = chatbot_response{msg, inference_time, tokens};

    return 0;
}

extern "C" int clean()
{
    llama_free(ctx);
    llama_free_model(model);
    llama_backend_free();
    return 0;
}
