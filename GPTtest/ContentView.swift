import SwiftUI
import Combine

// Struktury danych dla odpowiedzi API i lokalnej historii
struct ChatResponse: Codable {
    var id: String
    var object: String
    var created: Int
    var model: String
    var choices: [Choice]
    var usage: Usage?
}

struct Choice: Codable {
    var index: Int
    var message: MessageContent
    var logprobs: JSONNull?
    var finishReason: String?
}

struct MessageContent: Codable {
    var role: String
    var content: String
}

struct Usage: Codable {
    var promptTokens: Int?
    var completionTokens: Int?
    var totalTokens: Int?
}

struct JSONNull: Codable {
    public init() {}
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if !container.decodeNil() {
            throw DecodingError.typeMismatch(JSONNull.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for JSONNull"))
        }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }
}

struct Conversation: Identifiable {
    let id = UUID()
    var question: String
    var answer: String
}

// Główny widok aplikacji
struct ContentView: View {
    @State private var inputText: String = ""
    @State private var conversations = [Conversation]() // Lista przechowująca historię konwersacji
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        VStack {
            TextField("Wpisz swoje pytanie tutaj...", text: $inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("Wyślij") {
                callChatGPT(with: inputText)
            }
            .buttonStyle(DefaultButtonStyle())
            .padding()

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(conversations) { convo in
                        VStack(alignment: .leading) {
                            Text("Pytanie: \(convo.question)")
                                .bold()
                            Text("Odpowiedź: \(convo.answer)")
                                .padding(.top, 2)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
    }

    func callChatGPT(with text: String) {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.addValue("Bearer klucz", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = """
            {
                "model": "gpt-4o",
                "messages": [
                    {
                        "role": "user",
                        "content": "\(text)"
                    }
                ]
            }
        """.data(using: .utf8)

        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: ChatResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    print("Żądanie zakończone")
                case .failure(let error):
                    print("Błąd: \(error)")
                    // W przypadku błędu, dodajemy również do historii
                    self.conversations.insert(Conversation(question: text, answer: "Błąd: \(error.localizedDescription)"), at: 0)
                }
            }, receiveValue: { response in
                let answer = response.choices.first?.message.content ?? "Nie otrzymano odpowiedzi"
                self.conversations.insert(Conversation(question: text, answer: answer), at: 0)
                self.inputText = ""
            })
            .store(in: &cancellables)
    }
}
