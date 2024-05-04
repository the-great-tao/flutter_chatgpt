import 'package:dart_openai/openai.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_storage/get_storage.dart';

class ChatGPT {
  static final ChatGPT _instance = ChatGPT._();

  factory ChatGPT() => _getInstance();

  static ChatGPT get instance => _getInstance();

  ChatGPT._();

  static ChatGPT _getInstance() {
    return _instance;
  }

  static GetStorage storage = GetStorage();

  static String chatGptToken =
      dotenv.env['OPENAI_CHATGPT_TOKEN'] ?? ''; // token
  static String defaultModel = 'gpt-3.5-turbo';
  static List defaultRoles = [
    'system',
    'user',
    'assistant'
  ]; // generating | error

  static List chatModelList = [
    {
      "type": "chat",
      "name": "AI Chat",
      "desc": "Natural language chat, continuous conversation mode",
      "isContinuous": true,
      "content": "\nInstructions:"
          "\nYou are ChatGPT. The answer to each question should be as concise as possible. If you're making a list, don't have too many entries."
          " If possible, please format it in a friendly markdown format."
          '\n',
      "tips": [
        "Can you write a poem?",
        "Can you write a joke?",
        "Help me plan a trip",
      ],
    },
    {
      "type": "translationLanguage",
      "name": "Translate language",
      "desc": "Translate A language to B language",
      "isContinuous": false,
      "content": '\nnInstructions:\n'
          'I want you to act as a translator. You will recognize the language, translate it into the specified language and answer me. Please do not use an interpreter accent when translating, but to translate naturally, smoothly and authentically, using beautiful and elegant expressions. I will give you the format of "Translate A to B". If the format I gave is wrong, please tell me that the format of "Translate A to B" should be used. Please only answer the translation part, do not write the explanation.'
          " If possible, please format it in a friendly markdown format."
          '\n',
      "tips": [
        "Translate love to French",
        "Translate cute to French",
        "Translate How are you to French",
      ],
    },
  ];

  static Future<void> setOpenAIKey(String key) async {
    await storage.write('OpenAIKey', key);
    await initChatGPT();
  }

  static String getCacheOpenAIKey() {
    String? key = storage.read('OpenAIKey');
    if (key != null && key != '' && key != chatGptToken) {
      return key;
    }
    return '';
  }

  static Future<void> setOpenAIBaseUrl(String url) async {
    await storage.write('OpenAIBaseUrl', url);
    await initChatGPT();
  }

  static String getCacheOpenAIBaseUrl() {
    String? key = storage.read('OpenAIBaseUrl');
    return (key ?? "").isEmpty ? "" : key!;
  }

  static Set chatModelTypeList =
      chatModelList.map((map) => map['type']).toSet();

  /// 实现通过type获取信息
  static getAiInfoByType(String chatType) {
    return chatModelList.firstWhere(
      (item) => item['type'] == chatType,
      orElse: () => null,
    );
  }

  static Future<void> initChatGPT() async {
    String cacheKey = getCacheOpenAIKey();
    String cacheUrl = getCacheOpenAIBaseUrl();
    var apiKey = cacheKey != '' ? cacheKey : chatGptToken;
    OpenAI.apiKey = apiKey;
    if (apiKey != chatGptToken) {
      OpenAI.baseUrl =
          cacheUrl.isNotEmpty ? cacheUrl : "https://api.openai.com";
    }
  }

  static getRoleFromString(String role) {
    if (role == "system") return OpenAIChatMessageRole.system;
    if (role == "user") return OpenAIChatMessageRole.user;
    if (role == "assistant") return OpenAIChatMessageRole.assistant;
    return "unknown";
  }

  static convertListToModel(List messages) {
    List<OpenAIChatCompletionChoiceMessageModel> modelMessages = [];
    for (var element in messages) {
      modelMessages.add(OpenAIChatCompletionChoiceMessageModel(
        role: getRoleFromString(element["role"]),
        content: element["content"],
      ));
    }
    return modelMessages;
  }

  static List filterMessageParams(List messages) {
    List newMessages = [];
    for (var v in messages) {
      if (defaultRoles.contains(v['role'])) {
        newMessages.add({
          "role": v["role"],
          "content": v["content"],
        });
      }
    }
    return newMessages;
  }

  static Future<bool> checkRelation(
    List beforeMessages,
    Map message, {
    String model = '',
  }) async {
    beforeMessages = filterMessageParams(beforeMessages);
    String text = "\nInstructions:"
        "\nCheck whether the problem is related to the given conversation. If yes, return true. If no, return false. Please return only true or false. The answer length is 5."
        "\nquestion：$message}"
        "\nconversation：$beforeMessages"
        "\n";
    OpenAIChatCompletionModel chatCompletion = await sendMessage(
      [
        {
          "role": 'user',
          "content": text,
        }
      ],
      model: model,
    );
    debugPrint('---text $text---');
    String content = chatCompletion.choices.first.message.content ?? '';
    bool hasRelation = content.toLowerCase().contains('true');
    debugPrint('---检查问题前后关联度 $hasRelation---');
    return hasRelation;
  }

  static Future<OpenAIChatCompletionModel> sendMessage(
    List messages, {
    String model = '',
  }) async {
    messages = filterMessageParams(messages);
    List<OpenAIChatCompletionChoiceMessageModel> modelMessages =
        convertListToModel(messages);
    OpenAIChatCompletionModel chatCompletion =
        await OpenAI.instance.chat.create(
      model: model != '' ? model : defaultModel,
      messages: modelMessages,
    );
    return chatCompletion;
  }

  static Future sendMessageOnStream(
    List messages, {
    String model = '',
    Function? onProgress,
  }) async {
    messages = filterMessageParams(messages);
    List<OpenAIChatCompletionChoiceMessageModel> modelMessages =
        convertListToModel(messages);

    Stream<OpenAIStreamChatCompletionModel> chatStream =
        OpenAI.instance.chat.createStream(
      model: defaultModel,
      messages: modelMessages,
    );
    print(chatStream);

    chatStream.listen((chatStreamEvent) {
      print('---chatStreamEvent---');
      print('$chatStreamEvent');
      print('---chatStreamEvent end---');
      if (onProgress != null) {
        onProgress(chatStreamEvent);
      }
    });
  }

  static Future<OpenAIImageModel> genImage(String imageDesc) async {
    debugPrint('---genImage starting: $imageDesc---');
    OpenAIImageModel image = await OpenAI.instance.image.create(
      prompt: imageDesc,
      n: 1,
      size: OpenAIImageSize.size1024,
      responseFormat: OpenAIImageResponseFormat.url,
    );
    debugPrint('---genImage success: $image---');
    return image;
  }
}
