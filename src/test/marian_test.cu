#include <algorithm>
#include <chrono>
#include <iomanip>
#include <string>
#include <cstdio>
#include <boost/timer/timer.hpp>
#include <boost/chrono.hpp>

#include "marian.h"
#include "training/config.h"
#include "optimizers/optimizers.h"
#include "optimizers/clippers.h"
#include "data/batch_generator.h"
#include "data/corpus.h"

#include "models/dl4mt.h"
#include "models/gnmt.h"
#include "models/multi_gnmt.h"

int main(int argc, char** argv) {
  using namespace marian;
  using namespace data;

  auto options = New<Config>(argc, argv, false);

//  std::vector<std::string> files =
//    {"../test/mini.en",
////     "../test/mini.en",
//     "../test/mini.de"};
//
//  std::vector<std::string> vocab =
//    {"../benchmark/marian32K/train.tok.true.bpe.en.yml",
////     "../benchmark/marian32K/train.tok.true.bpe.en.yml",
//     "../benchmark/marian32K/train.tok.true.bpe.de.yml"};
//
//  YAML::Node& c = options->get();
//  c["train-sets"] = files;
//  c["vocabs"] = vocab;

  auto corpus = DataSet<Corpus>(options);
  BatchGenerator<Corpus> bg(corpus, options);

  auto graph = New<ExpressionGraph>();
  graph->setDevice(0);

  auto type = options->get<std::string>("type");
  Ptr<Seq2SeqBase> encdec;
  if(type == "gnmt")
    encdec = New<GNMT>(options);
  else if(type == "multi-gnmt")
    encdec = New<MultiGNMT>(options);
  else
    encdec = New<DL4MT>(options);

  //encdec->load(graph, "../benchmark/marian32K/model.160000.npz");

  graph->reserveWorkspaceMB(128);

  boost::timer::cpu_timer timer;
  size_t batches = 1;
  for(int i = 0; i < 1; ++i) {
    bg.prepare(false);
    while(bg) {
      auto batch = bg.next();
      batch->debug();

      auto costNode = encdec->build(graph, batch);
      //for(auto p : graph->params())
      //  debug(p, p->name());
      debug(costNode, "cost");

      //graph->graphviz("debug.dot");

      graph->forward();
      //graph->backward();

      batches++;
    }
  }

  encdec->save(graph, "test.npz", true);

  std::cout << std::endl;
  std::cout << timer.format(5, "%ws") << std::endl;

  return 0;
}
