# *RoseTTAFold* 
This package contains deep learning models and related scripts to run RoseTTAFold.  
This repository is the official implementation of RoseTTAFold: Accurate prediction of protein structures and interactions using a 3-track network.
Forked from https://github.com/RosettaCommons/RoseTTAFold.

使用说明：https://www.jianshu.com/p/be32a18087c1  
########################################################
1. 避开uniref30、BFD这两个超大数据包的下载、解压及运算
2. 修改了RoseTTAFold和folding环境文件，适合国内安装，提供了便捷的pyRosetta安装方式。
3. 使用网页工具获得MSA和二级结构文件
4. 可以在win10自带子linux系统下运行  
########################################################

## Installation

1. 下载源码
```
git clone https://github.com/LiuZhen106/RoseTTAFold.git
cd RoseTTAFold/
```

2. 创建RoseTTAFold环境和folding环境，运行run_e2e_ver_lz.sh只需要RoseTTAFold环境，运行run_pyrosetta_ver_lz.sh需要RoseTTAFold和folding环境。
```
# create conda environment for RoseTTAFold
#   If your NVIDIA driver compatible with cuda11
conda env create -f RoseTTAFold-linux-lz.yml

# create conda environment for pyRosetta folding & running DeepAccNet
conda env create -f folding-linux-lz.yml
```

3. Download network weights (under Rosetta-DL Software license -- please see below)  
While the code is licensed under the MIT License, the trained weights and data for RoseTTAFold are made available for non-commercial use only under the terms of the Rosetta-DL Software license. You can find details at https://files.ipd.uw.edu/pub/RoseTTAFold/Rosetta-DL_LICENSE.txt

```
wget https://files.ipd.uw.edu/pub/RoseTTAFold/weights.tar.gz
tar xfz weights.tar.gz
```

4. 下载二级结构模板文件
```
# structure templates (including *_a3m.ffdata, *_a3m.ffindex) [114G]
wget https://files.ipd.uw.edu/pub/RoseTTAFold/pdb100_2021Mar03.tar.gz
tar xfz pdb100_2021Mar03.tar.gz
```

## 使用方法
1. 通过在线服务器：https://toolkit.tuebingen.mpg.de/tools/hhblits 获取.a3m文件。
推荐的参数设置为：
E-value cutoff for inclusion: 1e-6 ~ 1e-3
Number of iterations: 2
Min probability in hitlist (%):50
Max target hits: 2000
2. 通过在线服务器：http://bioinf.cs.ucl.ac.uk/psipred/ 获取.horiz文件。

3. 新建工作文件夹，将蛋白质序列文件（fasta格式）、下载的.a3m文件（更名为t000_.msa0.a3m）、下载的.horiz文件（更名为t000_.msa0.horiz），共同放到工作目录下
```
# For monomer structure prediction
cd [test, example]
../run_[pyrosetta, e2e]_ver.sh input.fa .

# For complex modeling
# please see README file under example/complex_modeling/README for details.
python network/predict_complex.py -i paired.a3m -o complex -Ls 218 310 
```

## 预测结果
For the pyrosetta version, user will get five final models having estimated CA rms error at the B-factor column (model/model_[1-5].crderr.pdb).  
For the end-to-end version, there will be a single PDB output having estimated residue-wise CA-lddt at the B-factor column (t000_.e2e.pdb).

## FAQ
1. Segmentation fault while running hhblits/hhsearch  
For easy install, we used a statically compiled version of hhsuite (installed through conda). Currently, we're not sure what exactly causes segmentation fault error in some cases, but we found that it might be resolved if you compile hhsuite from source and use this compiled version instead of conda version. For installation of hhsuite, please see [here](https://github.com/soedinglab/hh-suite).

2. Submitting jobs to computing nodes  
The modeling pipeline provided here (run_pyrosetta_ver.sh/run_e2e_ver.sh) is a kind of guidelines to show how RoseTTAFold works. For more efficient use of computing resources, you might want to modify the provided bash script to submit separate jobs with proper dependencies for each of steps (more cpus/memory for hhblits/hhsearch, using gpus only for running the networks, etc). 

## Links:

* [Robetta server](https://robetta.bakerlab.org/) (RoseTTAFold option)
* [RoseTTAFold models for CASP14 targets](https://files.ipd.uw.edu/pub/RoseTTAFold/casp14_models.tar.gz) [input MSA and hhsearch files are included]

## Credit to performer-pytorch and SE(3)-Transformer codes
The code in the network/performer_pytorch.py is strongly based on [this repo](https://github.com/lucidrains/performer-pytorch) which is pytorch implementation of [Performer architecture](https://arxiv.org/abs/2009.14794).
The codes in network/equivariant_attention is from the original SE(3)-Transformer [repo](https://github.com/FabianFuchsML/se3-transformer-public) which accompanies [the paper](https://arxiv.org/abs/2006.10503) 'SE(3)-Transformers: 3D Roto-Translation Equivariant Attention Networks' by Fabian et al.


## References

M Baek, et al., Accurate prediction of protein structures and interactions using a 3-track network, bioRxiv (2021). [link](https://www.biorxiv.org/content/10.1101/2021.06.14.448402v1)

